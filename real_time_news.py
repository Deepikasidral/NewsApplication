import requests
import time
from datetime import datetime, timedelta

BASE_URL = "http://editorial.pti.in/ptiapi/webservice1.asmx/JsonFile1"
CENTER_CODE = "17102025001RL"

POLL_INTERVAL = 60       # seconds
WINDOW_MINUTES = 30      # look back window

seen_files = set()

def parse_pti_time(pti_time_str):
    try:
        return datetime.strptime(pti_time_str, "%A, %b %d, %Y %H:%M:%S")
    except Exception:
        return None


def fetch_recent():
    now = datetime.now()
    from_time = now - timedelta(minutes=WINDOW_MINUTES)

    params = {
        "centercode": CENTER_CODE,
        "FromTime": from_time.strftime("%Y-%m-%d %H:%M:%S"),
        "EndTime": now.strftime("%Y-%m-%d %H:%M:%S")
    }

    r = requests.get(BASE_URL, params=params, timeout=30)

    if r.status_code != 200 or not r.text.strip():
        return []

    try:
        return r.json()
    except Exception:
        return []


print("PTI REAL-TIME LATENCY MONITOR STARTED")
print("Polling every 60 seconds...\n")

while True:
    received_at = datetime.now()
    news = fetch_recent()

    for item in news:
        file_id = item.get("FileName")
        if not file_id or file_id in seen_files:
            continue

        seen_files.add(file_id)

        pti_time = parse_pti_time(item.get("PublishedAt"))
        if pti_time:
            delay_sec = int((received_at - pti_time).total_seconds())
            delay_min = round(delay_sec / 60, 2)
        else:
            delay_min = "N/A"

        print("NEW ARTICLE DETECTED")
        print("Headline      :", item.get("Headline"))
        print("PTI Published :", item.get("PublishedAt"))
        print("Received At   :", received_at.strftime("%Y-%m-%d %H:%M:%S"))
        print("Delay (mins)  :", delay_min)
        print("-" * 90)

    time.sleep(POLL_INTERVAL)