# summarizer.py
from fastapi import FastAPI, HTTPException
from pydantic import BaseModel
import openai
import os

openai.api_key = os.getenv("OPENAI_API_KEY")

app = FastAPI()

class NewsText(BaseModel):
    text: str

@app.post("/summarize")
async def summarize(news: NewsText):
    if not news.text:
        raise HTTPException(status_code=400, detail="No text provided")

    try:
        response = openai.ChatCompletion.create(
            model="gpt-4o-mini",
            messages=[
                {"role": "system", "content": "You are a helpful financial news summarizer."},
                {"role": "user", "content": f"Summarize this article in 3 sentences:\n\n{news.text}"}
            ]
        )
        summary = response.choices[0].message.content
        return {"summary": summary}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))
