from fastapi import FastAPI
from pydantic import BaseModel
from chatbot_service.chatbot import ask_bot

app = FastAPI(title="Rupee Letter Chatbot")

class ChatRequest(BaseModel):
    question: str

@app.post("/chat")
def chat(req: ChatRequest):
    answer = ask_bot(req.question)
    return {"answer": answer}

