#!/usr/bin/env bash

pip install -r requirements.txt
python manage.py collectstatic --noinput
pip install -r requirements.txt && python -m playwright install chromium