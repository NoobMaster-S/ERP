from django.contrib import admin
from .models import Business, BusinessUser


class BusinessUserInline(admin.TabularInline):
    model = BusinessUser
    extra = 0
    raw_id_fields = ('user', 'role', 'default_branch')


@admin.register(Business)
class BusinessAdmin(admin.ModelAdmin):
    list_display = ('name', 'slug', 'business_type', 'currency_code', 'phone', 'is_active', 'created_at')
    list_filter = ('business_type', 'is_active')
    search_fields = ('name', 'slug', 'email', 'phone')
    inlines = [BusinessUserInline]


@admin.register(BusinessUser)
class BusinessUserAdmin(admin.ModelAdmin):
    list_display = ('user', 'business', 'role', 'is_active', 'created_at')
    list_filter = ('is_active', 'role')
    search_fields = ('user__email', 'business__name')
