from datetime import date
from fastapi import HTTPException, Request
from mcp_server.db import db

rate_limits = db["rate_limits"]

MAX_REQUESTS_PER_DAY = 5


def check_rate_limit(request: Request):
    user_id = request.headers.get("X-User-Id")

    if not user_id:
        raise HTTPException(
            status_code=401,
            detail="User not authenticated"
        )

    today = date.today().isoformat()

    record = rate_limits.find_one({
        "user_id": user_id,
        "date": today
    })

    if record and record["count"] >= MAX_REQUESTS_PER_DAY:
        raise HTTPException(
            status_code=429,
            detail="Daily limit reached (5 questions/day)"
        )

    rate_limits.update_one(
        {"user_id": user_id, "date": today},
        {"$inc": {"count": 1}},
        upsert=True
    )
