# mcp_server/server.py
import asyncio
from contextlib import asynccontextmanager
from fastapi import FastAPI
from mcp_server.tools import mcp

@asynccontextmanager
async def lifespan(app: FastAPI):
    # Start MCP server when FastAPI starts
    await mcp.run()
    yield
    # Cleanup when FastAPI stops
    await mcp.cleanup()

app = FastAPI(lifespan=lifespan)

@app.get("/")
def root():
    return {"message": "MCP Server Running"}