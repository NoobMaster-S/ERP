import json
import uuid
from django.test import TestCase, Client
from django.contrib.auth import get_user_model
from apps.businesses.models import Business, BusinessUser
from apps.roles.services import initialize_tenant_roles
from apps.authentication.jwt_utils import create_access_token
from apps.common.permissions import get_user_tenant_permissions
from apps.synchronization.models import SyncOutboxLog

User = get_user_model()


class GraphQLAPITestCase(TestCase):
    def setUp(self):
        self.client = Client()
        self.user = User.objects.create_user(
            email='owner@acme-corp.com',
            password='StrongPassword123!',
            first_name='Owner',
            last_name='Acme'
        )
        self.business = Business.objects.create(
            name='Acme Corporation',
            slug='acme-corp',
            business_type='GENERAL'
        )
        roles = initialize_tenant_roles(self.business)
        self.owner_role = roles['Owner']
        BusinessUser.objects.create(
            business=self.business,
            user=self.user,
            role=self.owner_role
        )
        perms = get_user_tenant_permissions(self.user, self.business)
        self.access_token = create_access_token(self.user, tenant=self.business, permissions=perms)

    def test_graphql_healthz(self):
        response = self.client.get('/healthz/')
        self.assertEqual(response.status_code, 200)
        data = response.json()
        self.assertEqual(data['status'], 'healthy')

    def test_graphql_login_mutation(self):
        mutation = """
        mutation {
          login(input: {
            email: "owner@acme-corp.com",
            password: "StrongPassword123!"
          }) {
            accessToken
            user {
              email
              firstName
            }
            activeBusiness {
              name
              roleName
            }
          }
        }
        """
        response = self.client.post(
            '/graphql/',
            data=json.dumps({'query': mutation}),
            content_type='application/json'
        )
        self.assertEqual(response.status_code, 200)
        data = response.json()
        self.assertNotIn('errors', data)
        payload = data['data']['login']
        self.assertTrue(len(payload['accessToken']) > 10)
        self.assertEqual(payload['user']['email'], 'owner@acme-corp.com')
        self.assertEqual(payload['activeBusiness']['name'], 'Acme Corporation')

    def test_graphql_sync_outbox_idempotency(self):
        """
        Proves that submitting identical idempotency_key returns cached result without duplication.
        """
        idempotency_key = str(uuid.uuid4())
        mutation = f"""
        mutation {{
          ingestSyncBatch(input: {{
            items: [
              {{
                idempotencyKey: "{idempotency_key}",
                clientMutationId: "local-cust-1",
                mutationType: "CREATE_CUSTOMER",
                entityType: "Customer",
                payloadJson: "{{\\"name\\": \\"John Doe\\"}}"
              }}
            ]
          }}) {{
            processedCount
            results {{
              idempotencyKey
              isSuccess
              serverEntityId
            }}
          }}
        }}
        """

        headers = {
            'HTTP_AUTHORIZATION': f'Bearer {self.access_token}',
            'HTTP_X_BUSINESS_ID': str(self.business.id)
        }

        # First request
        res1 = self.client.post(
            '/graphql/',
            data=json.dumps({'query': mutation}),
            content_type='application/json',
            **headers
        )
        self.assertEqual(res1.status_code, 200)
        data1 = res1.json()['data']['ingestSyncBatch']
        self.assertEqual(data1['processedCount'], 1)
        server_id_1 = data1['results'][0]['serverEntityId']
        self.assertTrue(data1['results'][0]['isSuccess'])

        # Verify exactly 1 sync record in database
        self.assertEqual(SyncOutboxLog.objects.filter(idempotency_key=idempotency_key).count(), 1)

        # Second request with SAME idempotency key (idempotent replay)
        res2 = self.client.post(
            '/graphql/',
            data=json.dumps({'query': mutation}),
            content_type='application/json',
            **headers
        )
        self.assertEqual(res2.status_code, 200)
        data2 = res2.json()['data']['ingestSyncBatch']
        server_id_2 = data2['results'][0]['serverEntityId']

        # Server entity ID must match the original transaction
        self.assertEqual(server_id_1, server_id_2)
        # Database count remains exactly 1
        self.assertEqual(SyncOutboxLog.objects.filter(idempotency_key=idempotency_key).count(), 1)

    def test_create_customer_mutation(self):
        """
        Verify that createCustomer mutation creates customer record and returns CustomerType.
        """
        mutation = """
        mutation CreateCustomer($input: CreateCustomerInput!) {
          createCustomer(input: $input) {
            id
            name
            phone
            email
            currentBalance
            creditLimit
          }
        }
        """
        variables = {
            "input": {
                "name": "Jane Doe",
                "phone": "+1-555-987-6543",
                "email": "jane@example.com",
                "address": "123 Main St",
                "creditLimit": 1000.0,
                "initialBalance": 150.0,
            }
        }
        headers = {
            'HTTP_AUTHORIZATION': f'Bearer {self.access_token}',
            'HTTP_X_BUSINESS_ID': str(self.business.id)
        }
        res = self.client.post(
            '/graphql/',
            data=json.dumps({'query': mutation, 'variables': variables}),
            content_type='application/json',
            **headers
        )
        self.assertEqual(res.status_code, 200)
        data = res.json()
        self.assertNotIn('errors', data)
        cust_data = data['data']['createCustomer']
        self.assertEqual(cust_data['name'], 'Jane Doe')
        self.assertEqual(cust_data['phone'], '+1-555-987-6543')
        self.assertEqual(cust_data['currentBalance'], 150.0)
