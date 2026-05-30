from django.db import models
from django.contrib.auth.models import AbstractUser


class Users(AbstractUser):
    email = models.EmailField(unique=True)
    username = models.CharField(max_length=255,)
    is_verified = models.BooleanField(default=False)

    USERNAME_FIELD = 'email'
    REQUIRED_FIELDS = ['username']



class Otp(models.Model):
    email = models.EmailField(unique=True)
    otp = models.CharField(max_length=64)
    created_at = models.DateTimeField(auto_now_add=True)



    