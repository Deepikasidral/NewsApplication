import os
from dotenv import load_dotenv

BASE_DIR = os.path.dirname(os.path.abspath(__file__))  
ENV_PATH = os.path.join(BASE_DIR, ".env")

load_dotenv(dotenv_path=ENV_PATH)

MONGO_URI = os.getenv("MONGO_URI")
DB_NAME = os.getenv("DB_NAME")

AZURE_OPENAI_ENDPOINT = os.getenv("AZURE_OPENAI_ENDPOINT")
AZURE_OPENAI_KEY = os.getenv("AZURE_OPENAI_KEY")
AZURE_DEPLOYMENT = os.getenv("AZURE_DEPLOYMENT")

print("ENV PATH:", ENV_PATH)
print("AZURE_OPENAI_KEY loaded:", bool(AZURE_OPENAI_KEY))

if not AZURE_OPENAI_KEY:
    raise RuntimeError("AZURE_OPENAI_KEY not loaded from .env")
