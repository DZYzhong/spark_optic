#!/usr/bin/env python3
"""
Simple smoke check against local Spark Optic server.
Usage: ensure the server is running locally on 127.0.0.1:8000, then run:
    python3 scripts/smoke_check.py
"""
import sys
import json
from urllib.request import Request, urlopen
from urllib.error import URLError, HTTPError

BASE = "http://127.0.0.1:8000"

def get(path):
    req = Request(BASE + path)
    try:
        with urlopen(req, timeout=5) as r:
            return r.status, r.read().decode('utf-8')
    except HTTPError as e:
        return e.code, e.read().decode('utf-8')
    except URLError as e:
        print(f"failed to reach {path}: {e}")
        return None, None


def post(path, payload):
    data = json.dumps(payload).encode('utf-8')
    req = Request(BASE + path, data=data, headers={"Content-Type":"application/json"}, method='POST')
    try:
        with urlopen(req, timeout=5) as r:
            return r.status, r.read().decode('utf-8')
    except HTTPError as e:
        return e.code, e.read().decode('utf-8')
    except URLError as e:
        print(f"failed to reach {path}: {e}")
        return None, None


def main():
    s, body = get('/')
    print('/ ->', s)
    s, body = get('/api/system/status')
    print('/api/system/status ->', s, body)
    s, body = get('/api/tasks')
    print('/api/tasks ->', s, body)
    payload = {"task_key": "smoke_task", "events": [{"Event": "SparkListenerApplicationStart", "App ID": "smoke_app", "App Name": "smoke_task", "Timestamp": 1690000200000}, {"Event": "SparkListenerApplicationEnd", "Timestamp": 1690000205000}]}
    s, body = post('/api/listener/events', payload)
    print('/api/listener/events ->', s, body)
    # check metrics endpoint
    s, metrics = get('/metrics')
    print('/metrics ->', s)
    if s == 200 and metrics:
        # basic sanity: expect spark_optic_up and accepted_events_total to appear
        ok = False
        for line in metrics.splitlines():
            if line.startswith('spark_optic_accepted_events_total'):
                ok = True
                break
        print('metrics contains accepted_events_total:', ok)

if __name__ == '__main__':
    main()
