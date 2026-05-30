from django.urls import path
from myapp.auth.views.signup import SignupView
from myapp.auth.views.verify_signup import VerifySignupView
from myapp.auth.views.resend_otp import ResendOtpView
from myapp.auth.views.login import LoginView
from myapp.auth.views.logout import LogoutView
from myapp.auth.views.refresh_token import RefreshTokenView
from myapp.auth.views.forget_password import ForgetPasswordView

urlpatterns = [
    path('signup/', SignupView.as_view(), name='signup'),
    path('verify-signup/', VerifySignupView.as_view(), name='verify-signup'),
    path('resend-otp/', ResendOtpView.as_view(), name='resend-otp'),
    path('login/', LoginView.as_view(), name='login'),
    path('logout/', LogoutView.as_view(), name='logout'),
    path('refresh-token/', RefreshTokenView.as_view(), name='refresh-token'),
    path('forget-password/', ForgetPasswordView.as_view(), name='forget-password'),
    
]