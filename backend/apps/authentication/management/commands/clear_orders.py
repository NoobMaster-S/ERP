from django.core.management.base import BaseCommand
from django.db import transaction
# pyrefly: ignore [missing-import]
from apps.sales.models import Sale, SaleItem, InvoiceSequenceTracker
# pyrefly: ignore [missing-import]
from apps.inventory.models import StockMovement, MovementType
# pyrefly: ignore [missing-import]
from apps.synchronization.models import SyncOutboxLog


class Command(BaseCommand):
    help = "Clears all sales orders and transactions from the cloud database while preserving products and customers."

    @transaction.atomic
    def handle(self, *args, **options):
        self.stdout.write("Purging only orders and transactions...")

        # 1. Delete all sale items
        items_count = SaleItem.objects.all().count()
        SaleItem.objects.all().delete()

        # 2. Delete all sales
        sales_count = Sale.objects.all().count()
        Sale.objects.all().delete()

        # 3. Reset invoice counter back to starting sequence
        InvoiceSequenceTracker.objects.all().delete()

        # 4. Clean up sale stock movements
        StockMovement.objects.filter(movement_type=MovementType.SALE).delete()

        # 5. Clean up sale sync logs
        SyncOutboxLog.objects.filter(entity_type='Sale').delete()
        SyncOutboxLog.objects.filter(mutation_type='CREATE_SALE').delete()

        self.stdout.write(
            self.style.SUCCESS(
                f"Successfully deleted {sales_count} orders and {items_count} line items.\n"
                f"Invoice counters have been reset.\n"
                f"All products and customer accounts have been preserved!"
            )
        )
