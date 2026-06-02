FROM python:3.11

WORKDIR /app

COPY . .

RUN pip install -r requirements.txt

CMD gunicorn main.wsgi:application --bind 0.0.0.0:$PORT