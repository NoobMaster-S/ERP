from django.db import models, transaction
from apps.common.models import BaseModel, TenantModel


class Customer(TenantModel):
    name = models.CharField(max_length=255, db_index=True)
    phone = models.CharField(max_length=32, db_index=True, blank=True)
    email = models.EmailField(blank=True)
    address = models.TextField(blank=True)
    credit_limit = models.DecimalField(max_digits=14, decimal_places=2, default=0.0)
    current_balance = models.DecimalField(max_digits=14, decimal_places=2, default=0.0)  # Positive = Outstanding owed by customer
    is_active = models.BooleanField(default=True)
    version = models.PositiveIntegerField(default=1)

    class Meta:
        verbose_name = 'Customer'
        verbose_name_plural = 'Customers'
        ordering = ['name']

    def __str__(self):
        return f"{self.name} ({self.phone or 'No phone'})"


class InvoiceSequenceTracker(TenantModel):
    """
    Authoritative server sequence generator.
    Guarantees consecutive, collision-free legal invoice numbers per tenant, branch, and financial year.
    """
    branch = models.ForeignKey(
        'branches.Branch',
        on_delete=models.CASCADE,
        related_name='invoice_sequences',
        null=True,
        blank=True,
    )
    fiscal_year = models.CharField(max_length=16, default='2026-27', db_index=True)
    prefix = models.CharField(max_length=16, default='INV-')
    current_sequence = models.BigIntegerField(default=0)

    class Meta:
        verbose_name = 'Invoice Sequence Tracker'
        verbose_name_plural = 'Invoice Sequence Trackers'
        constraints = [
            models.UniqueConstraint(
                fields=['business', 'branch', 'fiscal_year', 'prefix'],
                name='uq_invoice_sequence_tracker'
            )
        ]

    @classmethod
    def get_next_invoice_number(cls, business, branch=None, fiscal_year='2026-27', prefix='INV-'):
        """
        Atomically increments and generates authoritative sequential invoice number using PostgreSQL row locking.
        """
        with transaction.atomic():
            tracker, created = cls.objects.select_for_update().get_or_create(
                business=business,
                branch=branch,
                fiscal_year=fiscal_year,
                prefix=prefix,
                defaults={'current_sequence': 0}
            )
            tracker.current_sequence += 1
            tracker.save(update_fields=['current_sequence', 'updated_at'])
            
            branch_tag = branch.code.upper() if branch and branch.code else "MAIN"
            seq_str = str(tracker.current_sequence).zfill(5)
            return f"{prefix}{branch_tag}-{fiscal_year}-{seq_str}"


class PaymentStatus(models.TextChoices):
    PENDING = 'PENDING', 'Pending Payment'
    PARTIAL = 'PARTIAL', 'Partially Paid'
    PAID = 'PAID', 'Fully Paid'


class PaymentMethod(models.TextChoices):
    CASH = 'CASH', 'Cash'
    CARD = 'CARD', 'Credit / Debit Card'
    UPI = 'UPI', 'UPI / QR Code'
    CREDIT = 'CREDIT', 'Khata / Customer Credit'
    BANK_TRANSFER = 'BANK_TRANSFER', 'Bank Transfer'
    MIXED = 'MIXED', 'Split / Mixed Payment'


class Sale(TenantModel):
    branch = models.ForeignKey(
        'branches.Branch',
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name='sales',
    )
    customer = models.ForeignKey(
        Customer,
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name='sales',
    )
    
    # Authoritative server invoice number
    invoice_number = models.CharField(max_length=64, db_index=True)
    # Temporary offline reference from mobile client (e.g. TEMP-POS01-00042)
    client_invoice_ref = models.CharField(max_length=64, blank=True, db_index=True)
    
    subtotal = models.DecimalField(max_digits=14, decimal_places=2, default=0.0)
    tax_amount = models.DecimalField(max_digits=14, decimal_places=2, default=0.0)
    discount_amount = models.DecimalField(max_digits=14, decimal_places=2, default=0.0)
    grand_total = models.DecimalField(max_digits=14, decimal_places=2)
    paid_amount = models.DecimalField(max_digits=14, decimal_places=2, default=0.0)
    
    payment_status = models.CharField(
        max_length=16,
        choices=PaymentStatus.choices,
        default=PaymentStatus.PAID,
    )
    payment_method = models.CharField(
        max_length=24,
        choices=PaymentMethod.choices,
        default=PaymentMethod.CASH,
    )
    
    idempotency_key = models.CharField(max_length=128, db_index=True)
    created_by = models.ForeignKey(
        'authentication.User',
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
    )

    class Meta:
        verbose_name = 'Sale'
        verbose_name_plural = 'Sales'
        ordering = ['-created_at']
        constraints = [
            models.UniqueConstraint(
                fields=['business', 'invoice_number'],
                name='uq_sale_business_invoice_number'
            ),
            models.UniqueConstraint(
                fields=['business', 'idempotency_key'],
                name='uq_sale_business_idempotency_key'
            )
        ]

    def __str__(self):
        return f"{self.invoice_number} - ₹{self.grand_total}"


class SaleItem(BaseModel):
    sale = models.ForeignKey(
        Sale,
        on_delete=models.CASCADE,
        related_name='items',
    )
    product = models.ForeignKey(
        'inventory.Product',
        on_delete=models.PROTECT,
        related_name='sale_items',
    )
    quantity = models.DecimalField(max_digits=12, decimal_places=3, default=1.0)
    unit_price = models.DecimalField(max_digits=14, decimal_places=2)
    tax_rate = models.DecimalField(max_digits=5, decimal_places=2, default=0.0)
    discount_amount = models.DecimalField(max_digits=14, decimal_places=2, default=0.0)
    line_total = models.DecimalField(max_digits=14, decimal_places=2)

    class Meta:
        verbose_name = 'Sale Item'
        verbose_name_plural = 'Sale Items'
