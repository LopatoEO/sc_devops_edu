FROM python:3.12-slim

WORKDIR /app

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

RUN groupadd --gid 10001 app \
    && useradd --uid 10001 --gid app --create-home --shell /usr/sbin/nologin app

COPY --chown=app:app app.py .

USER 10001:10001

CMD ["uvicorn", "app:app", "--host", "0.0.0.0", "--port", "8000"]
