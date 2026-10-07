from django.db import models
from apps.common.models import BaseModel


class BusinessType(models.TextChoices):
    RETAIL = 'RETAIL', 'Retail Shop / POS'
    JEWELLERY = 'JEWELLERY', 'Jewellery & Gold Business'
    ELECTRONICS = 'ELECTRONICS', 'Electronics & Appliances'
    GROCERY = 'GROCERY', 'Grocery & Supermarket'
    WHOLESALE = 'WHOLESALE', 'Wholesale Trader'
    DISTRIBUTOR = 'DISTRIBUTOR', 'Distributor / Supply Chain'
    SERVICE = 'SERVICE', 'Service Business'
    MANUFACTURING = 'MANUFACTURING', 'Small Manufacturing'
    RESTAURANT = 'RESTAURANT', 'Restaurant / Cafe'
    GENERAL = 'GENERAL', 'General Trading'


class Business(BaseModel):
    """
    Root Tenant model representing an independent business organization.
    All business data across the entire platform is strictly isolated per tenant.
    """
    name = models.CharField(max_length=255, db_index=True)
    slug = models.SlugField(max_length=128, unique=True, db_index=True)
    business_type = models.CharField(
        max_length=32,
        choices=BusinessType.choices,
        default=BusinessType.GENERAL,
    )
    
    # Financial & Localization Settings
    currency_code = models.CharField(max_length=3, default='INR')
    currency_symbol = models.CharField(max_length=8, default='₹')
    decimal_places = models.PositiveSmallIntegerField(default=2)
    timezone = models.CharField(max_length=64, default='Asia/Kolkata')
    
    # Contact & Legal
    tax_identification_number = models.CharField(max_length=64, blank=True)
    email = models.EmailField(blank=True)
    phone = models.CharField(max_length=32, blank=True)
    address = models.TextField(blank=True)
    logo_storage_key = models.CharField(max_length=255, blank=True)
    
    # Invoice Configuration Defaults
    invoice_prefix = models.CharField(max_length=16, default='INV-')
    quotation_prefix = models.CharField(max_length=16, default='EST-')
    
    is_active = models.BooleanField(default=True)

    class Meta:
        verbose_name = 'Business'
        verbose_name_plural = 'Businesses'
        ordering = ['name']

    def __str__(self):
        return f"{self.name} ({self.get_business_type_display()})"


class BusinessUser(BaseModel):
    """
    Associates a User with a Business tenant and grants an RBAC Role.
    """
    business = models.ForeignKey(
        Business,
        on_delete=models.CASCADE,
        related_name='memberships',
    )
    user = models.ForeignKey(
        'authentication.User',
        on_delete=models.CASCADE,
        related_name='business_memberships',
    )
    role = models.ForeignKey(
        'roles.Role',
        on_delete=models.PROTECT,
        related_name='memberships',
    )
    default_branch = models.ForeignKey(
        'branches.Branch',
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name='default_users',
    )
    is_active = models.BooleanField(default=True)

    class Meta:
        verbose_name = 'Business Membership'
        verbose_name_plural = 'Business Memberships'
        constraints = [
            models.UniqueConstraint(
                fields=['business', 'user'],
                name='uq_business_user_membership'
            )
        ]

    def __str__(self):
        return f"{self.user.email} @ {self.business.name} ({self.role.name})"
