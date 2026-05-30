# models.py

from django.db import models
from django.utils import timezone
from datetime import timedelta


class AIResponse(models.Model):

    ANALYSIS_TYPES = (
        ("fully_analysis", "Fully Analysis"),
        ("balance_sheet", "Balance Sheet"),
        ("income_statement", "Income Statement"),
        ("risk", "Risk Analysis"),
        ("technical", "Technical Analysis"),
    )

    stock_symbol = models.CharField(max_length=100)

    analysis_type = models.CharField(
        max_length=50,
        choices=ANALYSIS_TYPES
    )

    response = models.TextField()

    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        unique_together = ("stock_symbol", "analysis_type")

    def is_expired(self):
        return timezone.now() > self.updated_at + timedelta(hours=24)

    def __str__(self):
        return f"{self.stock_symbol} - {self.analysis_type}"