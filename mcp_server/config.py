import os
from dotenv import load_dotenv

BASE_DIR = os.path.dirname(os.path.abspath(__file__))
ENV_PATH = os.path.join(BASE_DIR, ".env")

load_dotenv(dotenv_path=ENV_PATH)

# =========================
# DATABASE CONFIG
# =========================
MONGO_URI = os.getenv("MONGO_URI")
DB_NAME = os.getenv("DB_NAME")

# =========================
# OPENAI CONFIG
# =========================
OPENAI_API_KEY = os.getenv("OPENAI_API_KEY")

print("ENV PATH:", ENV_PATH)
print("OPENAI_API_KEY loaded:", bool(OPENAI_API_KEY))

if not OPENAI_API_KEY:
    raise RuntimeError("OPENAI_API_KEY not loaded from .env")
