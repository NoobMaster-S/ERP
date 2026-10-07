from django.contrib import admin
from .models import Branch, Warehouse


@admin.register(Branch)
class BranchAdmin(admin.ModelAdmin):
    list_display = ('name', 'business', 'code', 'is_headquarters', 'is_active', 'created_at')
    list_filter = ('is_headquarters', 'is_active', 'business')
    search_fields = ('name', 'code', 'business__name')


@admin.register(Warehouse)
class WarehouseAdmin(admin.ModelAdmin):
    list_display = ('name', 'branch', 'business', 'code', 'is_default', 'is_active')
    list_filter = ('is_default', 'is_active', 'business')
    search_fields = ('name', 'code', 'branch__name')
