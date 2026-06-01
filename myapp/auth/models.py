from django.db import models
from django.db.models.signals import post_delete
from django.dispatch import receiver
from django.contrib.auth.models import AbstractUser
from django.utils import timezone


class Users(AbstractUser):
    email = models.EmailField(unique=True)
    username = models.CharField(max_length=255)
    is_verified = models.BooleanField(default=False)

    plan = models.CharField(max_length=32, default='free')
    premium_started_at = models.DateTimeField(null=True, blank=True)

    ai_requests_today = models.IntegerField(default=0)
    ai_requests_date = models.DateField(null=True, blank=True)
    # models.py - add to Users class
    ai_analysis_daily_limit = models.IntegerField(default=3)   # admin can bump this
    ai_analysis_used_today  = models.IntegerField(default=0)   # resets each day
    ai_analysis_date        = models.DateField(null=True, blank=True)  # tracks reset day

    feature_filter_penny = models.BooleanField(default=False)
    feature_filter_mid = models.BooleanField(default=False)
    feature_filter_large = models.BooleanField(default=False)
    feature_filter_growth = models.BooleanField(default=False)
    feature_analysis_unlimited = models.BooleanField(default=False)

    first_name = None
    last_name = None

    USERNAME_FIELD = 'email'
    REQUIRED_FIELDS = ['username']

    def is_premium_expired(self):
        if self.plan != 'premium' or not self.premium_started_at:
            return False
        now = timezone.now()
        started = self.premium_started_at
        try:
            expiry = started.replace(month=started.month + 1)
        except ValueError:
            import calendar
            last_day = calendar.monthrange(started.year, started.month + 1)[1]
            expiry = started.replace(month=started.month + 1, day=last_day)
        if started.month == 12:
            expiry = started.replace(year=started.year + 1, month=1)
        return now >= expiry

    def expire_premium(self):
        self.plan = 'free'
        self.premium_started_at = None
        self.feature_filter_penny = False
        self.feature_filter_mid = False
        self.feature_filter_large = False
        self.feature_filter_growth = False
        self.feature_analysis_unlimited = False
        self.save()


class Otp(models.Model):
    email = models.EmailField(unique=True)
    otp = models.CharField(max_length=64)
    created_at = models.DateTimeField(auto_now_add=True)


class ContactRequest(models.Model):
    STATUS_PENDING = 'pending'
    STATUS_APPROVED = 'approved'
    STATUS_REJECTED = 'rejected'
    STATUS_CHOICES = [
        (STATUS_PENDING, 'Pending'),
        (STATUS_APPROVED, 'Approved'),
        (STATUS_REJECTED, 'Rejected'),
    ]

    user = models.ForeignKey(Users, null=True, blank=True, on_delete=models.CASCADE)
    email = models.EmailField()
    phone = models.CharField(max_length=32, blank=True)

    ai_analysis_used = models.IntegerField(default=0)
    ai_analysis_limit = models.IntegerField(default=3)
    ai_analysis_remaining = models.IntegerField(default=3)

    request_filter_penny = models.BooleanField(default=False)
    request_filter_mid = models.BooleanField(default=False)
    request_filter_large = models.BooleanField(default=False)
    request_filter_growth = models.BooleanField(default=False)
    request_analysis_unlimited = models.BooleanField(default=False)

    extra_info = models.JSONField(blank=True, null=True)
    status = models.CharField(max_length=20, choices=STATUS_CHOICES, default=STATUS_PENDING)
    created_at = models.DateTimeField(auto_now_add=True)

    def __str__(self):
        return f"ContactRequest({self.email} - {self.status})"

    def save(self, *args, **kwargs):
        previous = None
        if self.pk:
            try:
                previous = ContactRequest.objects.get(pk=self.pk)
            except ContactRequest.DoesNotExist:
                pass

        just_approved = (
            self.status == self.STATUS_APPROVED
            and (previous is None or previous.status != self.STATUS_APPROVED)
        )

        super().save(*args, **kwargs)

        if not self.user or not just_approved:
            return

        if self.request_filter_penny:
            self.user.feature_filter_penny = True
        if self.request_filter_mid:
            self.user.feature_filter_mid = True
        if self.request_filter_large:
            self.user.feature_filter_large = True
        if self.request_filter_growth:
            self.user.feature_filter_growth = True
        if self.request_analysis_unlimited:
            self.user.feature_analysis_unlimited = True

        self.user.plan = 'premium'
        self.user.premium_started_at = timezone.now()
        self.user.save()


class AiAnalysisRecord(models.Model):
    user = models.ForeignKey(Users, on_delete=models.CASCADE)
    stock_symbol = models.CharField(max_length=32)
    date = models.DateField()
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        unique_together = (('user', 'stock_symbol', 'date'),)

    def __str__(self):
        return f"AiAnalysisRecord({self.user.email}, {self.stock_symbol}, {self.date})"


@receiver(post_delete, sender=Users)
def delete_user_related_data(sender, instance, **kwargs):
    Otp.objects.filter(email=instance.email).delete()