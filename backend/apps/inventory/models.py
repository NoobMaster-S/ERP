from django.db import models
from apps.common.models import BaseModel, TenantModel


class Category(TenantModel):
    name = models.CharField(max_length=128, db_index=True)
    slug = models.SlugField(max_length=128)
    description = models.TextField(blank=True)
    parent = models.ForeignKey(
        'self',
        on_delete=models.CASCADE,
        null=True,
        blank=True,
        related_name='subcategories',
    )
    is_active = models.BooleanField(default=True)

    class Meta:
        verbose_name = 'Category'
        verbose_name_plural = 'Categories'
        ordering = ['name']
        constraints = [
            models.UniqueConstraint(
                fields=['business', 'slug'],
                name='uq_category_business_slug'
            )
        ]

    def __str__(self):
        return f"{self.name} ({self.business.name})"


class ProductUnit(TenantModel):
    name = models.CharField(max_length=32)
    code = models.CharField(max_length=16)  # e.g. PCS, KG, G, LTR, MTR, BOX
    precision = models.PositiveSmallIntegerField(default=0)  # e.g. 0 for PCS, 2 for KG

    class Meta:
        verbose_name = 'Product Unit'
        verbose_name_plural = 'Product Units'
        constraints = [
            models.UniqueConstraint(
                fields=['business', 'code'],
                name='uq_unit_business_code'
            )
        ]

    def __str__(self):
        return f"{self.name} ({self.code})"


class Product(TenantModel):
    name = models.CharField(max_length=255, db_index=True)
    sku = models.CharField(max_length=64, db_index=True, blank=True)
    barcode = models.CharField(max_length=64, db_index=True, blank=True)
    description = models.TextField(blank=True)
    
    category = models.ForeignKey(
        Category,
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name='products',
    )
    unit = models.ForeignKey(
        ProductUnit,
        on_delete=models.PROTECT,
        null=True,
        blank=True,
        related_name='products',
    )
    
    cost_price = models.DecimalField(max_digits=14, decimal_places=2, default=0.0)
    selling_price = models.DecimalField(max_digits=14, decimal_places=2, default=0.0)
    tax_rate = models.DecimalField(max_digits=5, decimal_places=2, default=0.0)  # Percentage e.g. 18.00
    min_stock_threshold = models.DecimalField(max_digits=14, decimal_places=2, default=5.0)
    
    is_active = models.BooleanField(default=True)
    version = models.PositiveIntegerField(default=1)  # Optimistic lock for sync

    class Meta:
        verbose_name = 'Product'
        verbose_name_plural = 'Products'
        ordering = ['name']
        constraints = [
            models.UniqueConstraint(
                fields=['business', 'sku'],
                condition=~models.Q(sku=''),
                name='uq_product_business_sku'
            ),
            models.UniqueConstraint(
                fields=['business', 'barcode'],
                condition=~models.Q(barcode=''),
                name='uq_product_business_barcode'
            )
        ]

    def __str__(self):
        return f"{self.name} - ₹{self.selling_price}"


class WarehouseStock(TenantModel):
    product = models.ForeignKey(
        Product,
        on_delete=models.CASCADE,
        related_name='warehouse_stocks',
    )
    warehouse = models.ForeignKey(
        'branches.Warehouse',
        on_delete=models.CASCADE,
        related_name='product_stocks',
    )
    quantity_on_hand = models.DecimalField(max_digits=14, decimal_places=3, default=0.0)
    allocated_quantity = models.DecimalField(max_digits=14, decimal_places=3, default=0.0)

    class Meta:
        verbose_name = 'Warehouse Stock'
        verbose_name_plural = 'Warehouse Stocks'
        constraints = [
            models.UniqueConstraint(
                fields=['business', 'product', 'warehouse'],
                name='uq_warehouse_product_stock'
            )
        ]


class MovementType(models.TextChoices):
    PURCHASE = 'PURCHASE', 'Purchase Received'
    SALE = 'SALE', 'POS Sale'
    ADJUSTMENT = 'ADJUSTMENT', 'Stock Adjustment'
    RETURN = 'RETURN', 'Sales Return'
    INITIAL = 'INITIAL', 'Initial Stock'


class StockMovement(TenantModel):
    product = models.ForeignKey(
        Product,
        on_delete=models.CASCADE,
        related_name='movements',
    )
    warehouse = models.ForeignKey(
        'branches.Warehouse',
        on_delete=models.CASCADE,
        related_name='movements',
    )
    movement_type = models.CharField(max_length=32, choices=MovementType.choices)
    quantity_delta = models.DecimalField(max_digits=14, decimal_places=3)
    reference_id = models.CharField(max_length=128, blank=True)
    notes = models.TextField(blank=True)
    created_by = models.ForeignKey(
        'authentication.User',
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
    )

    class Meta:
        verbose_name = 'Stock Movement'
        verbose_name_plural = 'Stock Movements'
        ordering = ['-created_at']
