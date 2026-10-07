from django.test import TestCase
from django.contrib.auth import get_user_model
from apps.authentication.jwt_utils import (
    create_access_token,
    create_refresh_token,
    decode_jwt_token,
)
from apps.businesses.models import Business

User = get_user_model()


class AuthenticationTestCase(TestCase):
    def setUp(self):
        self.user = User.objects.create_user(
            email='testuser@example.com',
            password='SecurePassword123!',
            first_name='Test',
            last_name='User',
        )
        self.business = Business.objects.create(
            name='Test Business',
            slug='test-business',
        )

    def test_create_and_decode_access_token(self):
        permissions = {'sales.create', 'products.view'}
        token = create_access_token(
            user=self.user,
            tenant=self.business,
            permissions=permissions
        )
        self.assertIsNotNone(token)

        payload = decode_jwt_token(token)
        self.assertIsNotNone(payload)
        self.assertEqual(payload['sub'], str(self.user.id))
        self.assertEqual(payload['email'], self.user.email)
        self.assertEqual(payload['tenant_id'], str(self.business.id))
        self.assertIn('sales.create', payload['permissions'])
        self.assertIn('products.view', payload['permissions'])

    def test_create_and_decode_refresh_token(self):
        token = create_refresh_token(user=self.user, device_id='device-abc')
        payload = decode_jwt_token(token)
        self.assertIsNotNone(payload)
        self.assertEqual(payload['sub'], str(self.user.id))
        self.assertEqual(payload['device_id'], 'device-abc')
        self.assertEqual(payload['type'], 'refresh')

    def test_invalid_token_returns_none(self):
        payload = decode_jwt_token("totally.bogus.jwt.token")
        self.assertIsNone(payload)
