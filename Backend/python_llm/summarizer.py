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
