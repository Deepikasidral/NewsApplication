
from fastapi.middleware.cors import CORSMiddleware
from fastapi import FastAPI, Request
from pydantic import BaseModel
from mcp_server.llm import ask_llm
from mcp_server.rate_limiter import check_rate_limit

app = FastAPI(title="RupeeLetter Chat API")
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


class ChatRequest(BaseModel):
    question: str


@app.post("/chat")
async def chat(req: ChatRequest, request: Request):
    #check_rate_limit(request)
    answer = ask_llm(req.question)
    return {"answer": answer}