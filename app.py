from flask import Flask
import redis
import os

app = Flask(__name__)

redis_host = os.getenv('REDIS_HOST', 'redis1.myapp.local')
try:
    redis_client = redis.StrictRedis(host=redis_host, port=6379, db=0, decode_responses=True, socket_connect_timeout=5)
except e:
    print(f"Error connecting to Redis: {e}")

@app.route('/')
def index():
    if redis_client:
        counter = redis_client.incr('counter')
        return f'This page has been refreshed {counter} times.'
    else:
        return f'Error connecting to Redis. ENV is: {redis_host}'

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000, debug=True)

