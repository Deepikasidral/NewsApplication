# mcp_server/server.py
from contextlib import asynccontextmanager
from fastapi import FastAPI
from mcp_server.tools import mcp


@asynccontextmanager
async def lifespan(app: FastAPI):
    await mcp.run()
    yield
    await mcp.cleanup()


app = FastAPI(lifespan=lifespan)


@app.get("/")
def root():
    return {"message": "MCP Server Running"}
