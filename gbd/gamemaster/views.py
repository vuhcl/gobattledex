import hashlib
import hmac

import orjson
from django.conf import settings
from django.http import HttpResponse, HttpResponseForbidden
from django.shortcuts import render
from django.views.decorators.csrf import csrf_exempt
from django.views.decorators.http import require_POST

# Create your views here.


def latest_view(request):
    return render(request, "index.html")


def verify_signature(request):
    """Verify that the payload was sent from GitHub by validating SHA256"""
    signature_header = request.META.get('HTTP_X_HUB_SIGNATURE_256')
    if not signature_header:
        return HttpResponseForbidden("Signature header is missing!")
    hash_object = hmac.new(settings.GITHUB_WEBHOOK_SECRET.encode(
        'utf-8'), msg=request.body, digestmod=hashlib.sha256)
    expected_signature = "sha256=" + hash_object.hexdigest()
    if not hmac.compare_digest(expected_signature, signature_header):
        return HttpResponseForbidden("Request signatures didn't match!")
    return handle_event(request)


def handle_event(request):
    event = request.META.get('HTTP_X_GITHUB_EVENT')
    if event == "ping":
        return HttpResponse('Ping received', status=200)
    return HttpResponse('Webhook received', status=202)


@require_POST
@csrf_exempt
def update(request):
    # Check the X-Hub-Signature header to make sure this is a valid request.
    return verify_signature(request)
