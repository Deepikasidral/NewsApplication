from fastapi import FastAPI
from pydantic import BaseModel
from mcp_server.llm import ask_llm

app = FastAPI(title="RupeeLetter Chat API")

class ChatRequest(BaseModel):
    question: str

@app.post("/chat")
async def chat(req: ChatRequest):
    answer = ask_llm(req.question)
    return {"answer": answer}
