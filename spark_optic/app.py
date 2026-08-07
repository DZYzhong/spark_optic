from __future__ import annotations

from collections import defaultdict
from datetime import datetime, timedelta
from pathlib import Path
import json

from fastapi import FastAPI, HTTPException, Request
from fastapi.responses import HTMLResponse, JSONResponse, PlainTextResponse
from fastapi.templating import Jinja2Templates
import logging
import datetime
import json as _json

# configure module logger with JSON formatter
logger = logging.getLogger("spark_optic")
if not logger.handlers:
    handler = logging.StreamHandler()

    class JSONFormatter(logging.Formatter):
        def format(self, record: logging.LogRecord) -> str:
            ts = datetime.datetime.utcfromtimestamp(record.created).replace(tzinfo=datetime.timezone.utc).isoformat()
            payload = {
                "timestamp": ts,
                "level": record.levelname,
                "logger": record.name,
                "message": record.getMessage(),
            }
            # include exception info if present
            if record.exc_info:
                payload["exc_info"] = self.formatException(record.exc_info)
            try:
                return _json.dumps(payload, ensure_ascii=False)
            except Exception:
                return _json.dumps({"message": record.getMessage()})

    formatter = JSONFormatter()
    handler.setFormatter(formatter)
    logger.addHandler(handler)
logger.setLevel(logging.INFO)

from .business_date import parse_business_date
from .config import Settings
from .ingestion.eventlog import parse_eventlog_lines
from .ingestion.history_server import SparkHistoryServerPuller
from .repositories import SparkOpticRepository, create_repository


BASE_DIR = Path(__file__).resolve().parent
templates = Jinja2Templates(directory=str(BASE_DIR / "templates"))


def _format_bytes(value: object) -> str:
    size = float(value or 0)
    units = ["B", "KB", "MB", "GB", "TB", "PB"]
    unit = units[0]
    for unit in units:
      ... (truncated for brevity)