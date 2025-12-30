# AI Overview MCP Server

Flask-based MCP server that generates AI-powered company overviews using Groq API and Finedge financial data.

## Setup

1. Install dependencies:
```bash
pip install -r requirements.txt
```

2. Configure environment:
- Copy `.env.example` to `.env`
- Add your Finedge API token

3. Run server:
```bash
python app.py
```

Server runs on `http://localhost:5001`

## Endpoints

### GET /api/ai-overview/:symbol
Generate AI overview for a company

Query Parameters:
- `company_name` (optional): Company name for context

Response:
```json
{
  "success": true,
  "company_name": "TCS",
  "symbol": "TCS",
  "overview": "AI-generated overview...",
  "generated_at": "2024-01-01T12:00:00"
}
```

### GET /health
Health check endpoint
