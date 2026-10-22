import os
import logging

from fastapi import FastAPI
from fastapi.responses import RedirectResponse
from dotenv import load_dotenv
from routers.journal_router import router as journal_router

load_dotenv()

LOG_LEVEL = os.getenv("LOG_LEVEL", "INFO").upper()
logging.basicConfig(
    level=LOG_LEVEL,
    format="%(asctime)s %(levelname)s %(name)s: %(message)s",
)
logger = logging.getLogger("journal")
logger.info("LearningSteps API started (env=%s, log level=%s)", os.getenv("APP_ENV", "unknown"), LOG_LEVEL)

app = FastAPI(title="LearningSteps API- deployed by pipeline", description="A simple learning journal API for tracking daily work, struggles, and intentions")
app.include_router(journal_router)


@app.get("/", include_in_schema=False)
def root():
    return RedirectResponse(url="/docs")
