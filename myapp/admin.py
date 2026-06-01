from django.contrib import admin
from myapp.auth.models import AiAnalysisRecord
# admin.py
from myapp.auth.models import Users, ContactRequest

@admin.register(Users)
class UsersAdmin(admin.ModelAdmin):
	list_display = ('id', 'email', 'username', 'plan', 'is_active', 'is_verified')
	search_fields = ('email', 'username')

@admin.register(ContactRequest)
class ContactRequestAdmin(admin.ModelAdmin):
	list_display = ('id', 'email', 'phone', 'status', 'request_filter_penny', 'request_filter_mid', 'request_filter_large', 'request_filter_growth', 'request_analysis_unlimited', 'created_at')
	list_filter = ('status',)
	search_fields = ('email', 'phone')
	actions = ['approve_requests']

	def approve_requests(self, request, queryset):
		for contact in queryset:
			contact.status = ContactRequest.STATUS_APPROVED
			contact.save()
	approve_requests.short_description = 'Approve selected contact requests'


@admin.register(AiAnalysisRecord)
class AiAnalysisRecordAdmin(admin.ModelAdmin):
	list_display = ('id', 'user', 'stock_symbol', 'date', 'created_at')
	search_fields = ('user__email', 'stock_symbol')

# Register your models here.
