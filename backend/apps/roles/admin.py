from django.contrib import admin
from .models import Role, Permission, RolePermission


class RolePermissionInline(admin.TabularInline):
    model = RolePermission
    extra = 1
    autocomplete_fields = ('permission',)


@admin.register(Permission)
class PermissionAdmin(admin.ModelAdmin):
    list_display = ('id', 'module', 'description')
    list_filter = ('module',)
    search_fields = ('id', 'description')


@admin.register(Role)
class RoleAdmin(admin.ModelAdmin):
    list_display = ('name', 'business', 'is_system', 'created_at')
    list_filter = ('is_system', 'business')
    search_fields = ('name',)
    inlines = [RolePermissionInline]
