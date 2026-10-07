import os
from django.core.management.base import BaseCommand
from django.contrib.auth import get_user_model
from django.utils.text import slugify
# pyrefly: ignore [missing-import]
from apps.businesses.models import Business, BusinessUser
# pyrefly: ignore [missing-import]
from apps.roles.services import initialize_tenant_roles
# pyrefly: ignore [missing-import]
from apps.branches.models import Branch, Warehouse

User = get_user_model()


class Command(BaseCommand):
    help = "Initializes an initial owner user and business organization if none exist."

    def add_arguments(self, parser):
        parser.add_argument(
            '--email',
            type=str,
            default=os.getenv('OWNER_EMAIL', 'owner@acme-corp.com'),
            help='Owner account email'
        )
        parser.add_argument(
            '--password',
            type=str,
            default=os.getenv('OWNER_PASSWORD', 'StrongPassword123!'),
            help='Owner account password'
        )
        parser.add_argument(
            '--business-name',
            type=str,
            default=os.getenv('BUSINESS_NAME', 'Acme Retail Store'),
            help='Initial business tenant name'
        )

    def handle(self, *args, **options):
        email = options['email'].strip().lower()
        password = options['password']
        business_name = options['business_name'].strip()

        # 1. Ensure or retrieve User
        user = User.objects.filter(email=email).first()
        if not user:
            user = User.objects.create_user(
                email=email,
                password=password,
                first_name="Store",
                last_name="Owner",
                is_staff=True,
                is_platform_admin=True,
            )
            self.stdout.write(self.style.SUCCESS(f"Created owner user: {email}"))
        else:
            # Update password if explicitly requested
            user.set_password(password)
            user.is_active = True
            user.is_staff = True
            user.is_platform_admin = True
            user.save()
            self.stdout.write(self.style.SUCCESS(f"Updated existing owner user: {email}"))

        # 2. Ensure or retrieve Business tenant
        slug = slugify(business_name) or "main-store"
        business = Business.objects.filter(slug=slug).first()
        if not business:
            business = Business.objects.create(
                name=business_name,
                slug=slug,
                email=email,
                currency_code='INR',
                currency_symbol='₹',
                decimal_places=2,
            )
            self.stdout.write(self.style.SUCCESS(f"Created business tenant: {business_name} (slug: {slug})"))
        else:
            self.stdout.write(self.style.SUCCESS(f"Business tenant already exists: {business.name}"))

        # 3. Initialize default roles
        roles_dict = initialize_tenant_roles(business)
        owner_role = roles_dict.get('Owner')

        # 4. Ensure HQ branch
        hq_branch, created_branch = Branch.objects.get_or_create(
            business=business,
            is_headquarters=True,
            defaults={'name': 'Main Branch', 'code': 'HQ', 'is_active': True}
        )
        if created_branch:
            self.stdout.write(self.style.SUCCESS("Created HQ Branch"))

        # 5. Ensure Main Warehouse
        wh, created_wh = Warehouse.objects.get_or_create(
            business=business,
            branch=hq_branch,
            is_default=True,
            defaults={'name': 'Main Warehouse', 'code': 'WH-MAIN', 'is_active': True}
        )
        if created_wh:
            self.stdout.write(self.style.SUCCESS("Created Main Warehouse"))

        # 6. Ensure BusinessUser membership
        membership, created_mem = BusinessUser.objects.get_or_create(
            business=business,
            user=user,
            defaults={'role': owner_role, 'is_active': True}
        )
        if not created_mem and membership.role != owner_role:
            membership.role = owner_role
            membership.is_active = True
            membership.save()

        self.stdout.write(
            self.style.SUCCESS(
                f"Setup complete! Owner: {email} can now authenticate to business '{business_name}'."
            )
        )
