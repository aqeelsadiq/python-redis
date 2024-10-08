FROM python:3.9-slim
WORKDIR /app
COPY . /app/
ENV REDIS_HOST=$REDIS_HOST
RUN pip install --no-cache-dir -r requirements.txt
EXPOSE 5000
CMD ["python", "app.py"]
