from fastapi import FastAPI, APIRouter, HTTPException
from dotenv import load_dotenv
from starlette.middleware.cors import CORSMiddleware
from motor.motor_asyncio import AsyncIOMotorClient
import os
import logging
from pathlib import Path
from pydantic import BaseModel, Field, ConfigDict
from typing import List, Optional
import uuid
from datetime import datetime, timezone


ROOT_DIR = Path(__file__).parent
load_dotenv(ROOT_DIR / '.env')

# MongoDB connection
mongo_url = os.environ['MONGO_URL']
client = AsyncIOMotorClient(mongo_url)
db = client[os.environ['DB_NAME']]

app = FastAPI(title="y666suf.com API")
api_router = APIRouter(prefix="/api")


# ====== Models ======
class StatusCheck(BaseModel):
    model_config = ConfigDict(extra="ignore")
    id: str = Field(default_factory=lambda: str(uuid.uuid4()))
    client_name: str
    timestamp: datetime = Field(default_factory=lambda: datetime.now(timezone.utc))


class StatusCheckCreate(BaseModel):
    client_name: str


class ScoreCreate(BaseModel):
    player_name: str = Field(..., min_length=1, max_length=32)
    score: int = Field(..., ge=0)
    game: str = Field(default="nfg_crash", max_length=32)
    multiplier: Optional[float] = Field(default=None, ge=0)


class ScoreEntry(BaseModel):
    model_config = ConfigDict(extra="ignore")
    id: str
    player_name: str
    score: int
    game: str
    multiplier: Optional[float] = None
    created_at: str


# ====== Routes ======
@api_router.get("/")
async def root():
    return {"message": "y666suf api online", "status": "ok"}


@api_router.post("/status", response_model=StatusCheck)
async def create_status_check(input: StatusCheckCreate):
    status_obj = StatusCheck(**input.model_dump())
    doc = status_obj.model_dump()
    doc['timestamp'] = doc['timestamp'].isoformat()
    await db.status_checks.insert_one(doc)
    return status_obj


@api_router.get("/status", response_model=List[StatusCheck])
async def get_status_checks():
    checks = await db.status_checks.find({}, {"_id": 0}).to_list(1000)
    for c in checks:
        if isinstance(c.get('timestamp'), str):
            c['timestamp'] = datetime.fromisoformat(c['timestamp'])
    return checks


# ====== Leaderboard ======
@api_router.post("/leaderboard/score", response_model=ScoreEntry)
async def submit_score(payload: ScoreCreate):
    entry = {
        "id": str(uuid.uuid4()),
        "player_name": payload.player_name.strip()[:32],
        "score": int(payload.score),
        "game": payload.game.lower().strip()[:32] or "nfg_crash",
        "multiplier": payload.multiplier,
        "created_at": datetime.now(timezone.utc).isoformat(),
    }
    await db.leaderboard.insert_one(entry.copy())
    return ScoreEntry(**entry)


@api_router.get("/leaderboard", response_model=List[ScoreEntry])
async def get_leaderboard(game: str = "nfg_crash", limit: int = 25):
    if limit > 100:
        limit = 100
    cursor = db.leaderboard.find({"game": game.lower()}, {"_id": 0}).sort("score", -1).limit(limit)
    items = await cursor.to_list(length=limit)
    return [ScoreEntry(**it) for it in items]


@api_router.delete("/leaderboard/{entry_id}")
async def delete_score(entry_id: str):
    result = await db.leaderboard.delete_one({"id": entry_id})
    if result.deleted_count == 0:
        raise HTTPException(status_code=404, detail="entry not found")
    return {"deleted": True}


@api_router.post("/leaderboard/seed")
async def seed_leaderboard():
    """Seed the leaderboard with sample data if empty (idempotent)."""
    existing = await db.leaderboard.count_documents({"game": "nfg_crash"})
    if existing >= 10:
        return {"seeded": False, "count": existing}

    samples = [
        ("VOIDRUNNER", 98420, 24.6),
        ("NEONGHOST", 87210, 19.3),
        ("ASTRO_KID", 76155, 17.1),
        ("ZER0COOL", 71044, 15.8),
        ("KAIJU99", 65990, 14.2),
        ("PIXEL.WITCH", 60412, 12.9),
        ("CTRL_FREAK", 54880, 11.4),
        ("MEGAHURTZ", 49230, 10.6),
        ("HYPERWAVE", 44119, 9.2),
        ("SUBZERO", 38770, 8.1),
        ("GLITCH404", 33422, 7.4),
        ("LUNARLOOP", 28311, 6.0),
    ]
    docs = []
    for name, score, mult in samples:
        docs.append({
            "id": str(uuid.uuid4()),
            "player_name": name,
            "score": score,
            "game": "nfg_crash",
            "multiplier": mult,
            "created_at": datetime.now(timezone.utc).isoformat(),
        })
    await db.leaderboard.insert_many([d.copy() for d in docs])
    return {"seeded": True, "count": len(docs)}


# Include router
app.include_router(api_router)

app.add_middleware(
    CORSMiddleware,
    allow_credentials=True,
    allow_origins=os.environ.get('CORS_ORIGINS', '*').split(','),
    allow_methods=["*"],
    allow_headers=["*"],
)

logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(name)s - %(levelname)s - %(message)s')
logger = logging.getLogger(__name__)


@app.on_event("shutdown")
async def shutdown_db_client():
    client.close()
