# import os
# import hashlib
# import json
# from datetime import datetime, timedelta
# from typing import List, Optional

# import motor.motor_asyncio
# from fastapi import FastAPI, HTTPException, Query
# from pydantic import BaseModel
# import httpx
# from bs4 import BeautifulSoup

# # Load env
# from dotenv import load_dotenv
# load_dotenv()

# OPENAI_API_KEY = os.getenv("OPENAI_API_KEY")
# PTI_CENTER_CODE = os.getenv("PTI_CENTER_CODE")
# MONGODB_URI = os.getenv("MONGODB_URI", "mongodb://localhost:27017")
# DB_NAME = os.getenv("DB_NAME", "news_summarizer_db")

# if not PTI_CENTER_CODE:
#     raise RuntimeError("PTI_CENTER_CODE must be set in environment")

# # Initialize MongoDB (Motor)
# client = motor.motor_asyncio.AsyncIOMotorClient(MONGODB_URI)
# db = client[DB_NAME]
# summaries_col = db["summaries"]       # stores summary docs keyed by key_id
# articles_col = db["articles"]         # optional full article store

# app = FastAPI(title="PTI Summarizer (MongoDB + Simple Summarizer)")

# # ---------------------
# # Models
# # ---------------------
# class SummarizeRequest(BaseModel):
#     text: str

# class ArticleItem(BaseModel):
#     FileName: Optional[str] = None
#     link: Optional[str] = None
#     slug: Optional[str] = None
#     category: Optional[str] = None
#     subcategory: Optional[str] = None
#     source: Optional[str] = None
#     EDNote: Optional[str] = None
#     Byline: Optional[str] = None
#     PublishedAt: Optional[str] = None
#     Priority: Optional[str] = None
#     Headline: Optional[str] = None
#     Copyrights: Optional[str] = None
#     story: Optional[str] = None

# # ---------------------
# # Helpers
# # ---------------------
# def make_key_for_article(item: dict) -> str:
#     """Prefer unique FileName if present, else hash the headline+published time+link/story."""
#     if item.get("FileName"):
#         return str(item["FileName"])
#     base = (item.get("Headline", "") or "") + "|" + (item.get("PublishedAt", "") or "") + "|" + (item.get("link", "") or "")
#     return hashlib.sha256(base.encode("utf-8")).hexdigest()

# def strip_html(html: str) -> str:
#     if not html:
#         return ""
#     soup = BeautifulSoup(html, "html.parser")
#     paragraphs = [p.get_text(strip=True) for p in soup.find_all("p")]
#     if paragraphs:
#         return "\n\n".join(paragraphs)
#     return soup.get_text(separator=" ", strip=True)

# def parse_pti_published_at(s: Optional[str]) -> Optional[str]:
#     if not s:
#         return None
#     s = s.strip()
#     try:
#         dt = datetime.strptime(s, "%A, %b %d, %Y %H:%M:%S")
#         return dt.isoformat()
#     except Exception:
#         try:
#             dt = datetime.fromisoformat(s)
#             return dt.isoformat()
#         except Exception:
#             return None

# async def fetch_pti_json(from_hours: int = 24) -> List[dict]:
#     now = datetime.now()
#     from_time = (now - timedelta(hours=from_hours)).strftime("%Y/%m/%d %H:%M:%S")
#     end_time = now.strftime("%Y/%m/%d %H:%M:%S")
#     url = (
#         "http://editorial.pti.in/ptiapi/webservice1.asmx/JsonFile1"
#         f"?centercode={PTI_CENTER_CODE}"
#         f"&FromTime={httpx.utils.quote(from_time)}"
#         f"&EndTime={httpx.utils.quote(end_time)}"
#     )

#     async with httpx.AsyncClient(timeout=20) as client:
#         resp = await client.get(url)
#         if resp.status_code != 200:
#             raise HTTPException(status_code=resp.status_code, detail="Failed to fetch PTI feed")
#         text = resp.text.strip()
#         if text.startswith("<"):
#             for tag in ["<string>", "</string>"]:
#                 text = text.replace(tag, "")
#             text = text.strip()
#         try:
#             data = json.loads(text)
#             return data if isinstance(data, list) else []
#         except Exception:
#             return []

# # ---------------------
# # Simple placeholder summarizer
# # ---------------------
# def simple_summarize(text: str) -> str:
#     """Return first 3 sentences as a simple summary."""
#     sentences = [s.strip() for s in text.replace("\n", " ").split(".") if s.strip()]
#     return ". ".join(sentences[:3]) + ("." if sentences else "")

# # ---------------------
# # API endpoints
# # ---------------------
# @app.post("/summarize")
# async def summarize_endpoint(req: SummarizeRequest):
#     text = req.text or ""
#     if not text.strip():
#         raise HTTPException(status_code=400, detail="No text provided")
#     key_id = hashlib.sha256(text.encode("utf-8")).hexdigest()

#     cached = await summaries_col.find_one({"key_id": key_id})
#     if cached:
#         return {"summary": cached["summary"], "cached": True}

#     summary = simple_summarize(text)

#     doc = {
#         "key_id": key_id,
#         "text": text,
#         "summary": summary,
#         "created_at": datetime.utcnow(),
#     }
#     await summaries_col.insert_one(doc)
#     return {"summary": summary, "cached": False}

# @app.get("/raw-pti")
# async def raw_pti(hours: int = Query(24, ge=1, le=168)):
#     data = await fetch_pti_json(from_hours=hours)
#     return {"count": len(data), "data": data}

# @app.get("/fetch-and-summarize")
# async def fetch_and_summarize(hours: int = Query(24, ge=1, le=168), limit: int = Query(50, ge=1, le=500)):
#     raw = await fetch_pti_json(from_hours=hours)
#     processed = []
#     count_new = 0

#     raw = list(raw)
#     def published_key(item):
#         dt = item.get("PublishedAt")
#         parsed = parse_pti_published_at(dt) if dt else None
#         return parsed or item.get("FileName") or ""
#     raw.sort(key=published_key, reverse=True)

#     for item in raw[:limit]:
#         key = make_key_for_article(item)
#         existing = await summaries_col.find_one({"key_id": key})
#         if existing:
#             processed.append({
#                 "key_id": key,
#                 "title": existing.get("title"),
#                 "summary": existing.get("summary"),
#                 "tags": existing.get("tags", []),
#                 "url": existing.get("url"),
#                 "published_at": existing.get("published_at"),
#                 "cached": True
#             })
#             continue

#         story_text = strip_html(item.get("story") or "")
#         if not story_text.strip():
#             story_text = item.get("Headline") or item.get("slug") or ""
#         summary_text = simple_summarize(story_text) if story_text.strip() else ""

#         tags = []
#         if item.get("category"):
#             tags.append(f"#{item.get('category')}")
#         if item.get("subcategory"):
#             tags.append(f"#{item.get('subcategory').strip()}")

#         doc = {
#             "key_id": key,
#             "file_name": item.get("FileName"),
#             "title": item.get("Headline") or item.get("slug") or "Untitled",
#             "text": story_text,
#             "summary": summary_text,
#             "tags": tags,
#             "url": item.get("link"),
#             "published_at": parse_pti_published_at(item.get("PublishedAt")),
#             "created_at": datetime.utcnow()
#         }

#         await summaries_col.insert_one(doc)
#         count_new += 1
#         processed.append({
#             "key_id": key,
#             "title": doc["title"],
#             "summary": doc["summary"],
#             "tags": doc["tags"],
#             "url": doc["url"],
#             "published_at": doc["published_at"],
#             "cached": False
#         })

#     processed.sort(key=lambda x: x.get("published_at") or "", reverse=True)
#     return {"count_processed": len(processed), "new_added": count_new, "items": processed}

# @app.get("/news")
# async def get_news(limit: int = Query(50, ge=1, le=500), skip: int = 0):
#     cursor = summaries_col.find().sort("created_at", -1).skip(skip).limit(limit)
#     out = []
#     async for doc in cursor:
#         out.append({
#             "key_id": doc.get("key_id"),
#             "file_name": doc.get("file_name"),
#             "title": doc.get("title"),
#             "summary": doc.get("summary"),
#             "tags": doc.get("tags", []),
#             "url": doc.get("url"),
#             "published_at": doc.get("published_at"),
#             "created_at": doc.get("created_at").isoformat() if doc.get("created_at") else None
#         })
#     return {"count": len(out), "items": out}
# main.py

from fastapi import FastAPI, HTTPException, Request
from pydantic import BaseModel
import os
from groq import Groq
from openai import OpenAI
from dotenv import load_dotenv
from bs4 import BeautifulSoup
import logging

# Setup logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# Load .env
load_dotenv()
GROQ_API_KEY = os.getenv("GROQ_API_KEY")
if not GROQ_API_KEY:
    raise ValueError("GROQ_API_KEY not set in .env")

client = Groq(api_key=GROQ_API_KEY)

# Create FastAPI instance
app = FastAPI(title="Simple PTI GPT Summarizer")

# Pydantic request model
class SummarizeRequest(BaseModel):
    text: str

# Helper to clean HTML
def clean_html(html_text: str) -> str:
    return BeautifulSoup(html_text, "html.parser").get_text(separator="\n").strip()

@app.middleware("http")
async def log_requests(request: Request, call_next):
    logger.info(f"Incoming request: {request.method} {request.url}")
    try:
        response = await call_next(request)
        logger.info(f"Response status: {response.status_code}")
        return response
    except Exception as e:
        logger.exception("Unhandled exception:")
        raise

# Summarize endpoint
@app.post("/summarize")
async def summarize_article(req: SummarizeRequest):
    text = req.text or ""
    if not text.strip():
        raise HTTPException(status_code=400, detail="No text provided")

    # Clean HTML
    text = clean_html(text)

    # ✅ Print full text to console for testing
    logger.info(f"Full story text:\n{text}\n")
    print("=== FULL STORY START ===")
    print(text)
    print("=== FULL STORY END ===")

    try:
        response = client.chat.completions.create(
            model="llama-3.1-8b-instant",
            messages=[
                {"role": "system", "content": "You are a news summarizer."},
                {"role": "user", "content": f"Summarize this news article in 3-4 sentences:\n\n{text}"}
            ],
            temperature=0.3,
            max_tokens=200
        )
        summary = response.choices[0].message.content.strip()
        logger.info(f"Generated summary: {summary}")
        return {"summary": summary}
    except Exception as e:
        logger.exception("LLM error:")
        raise HTTPException(status_code=500, detail=f"LLM error: {str(e)}")
