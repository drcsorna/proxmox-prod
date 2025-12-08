"""
Flow Journal - FastAPI Backend
Minimal, production-ready backend for daily journaling with emotion tracking
"""

from fastapi import FastAPI, HTTPException, Depends, status
from fastapi.security import HTTPBasic, HTTPBasicCredentials
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
from typing import Optional, List
from datetime import date, datetime
import asyncpg
import hashlib
import secrets
import os

# Environment variables
POSTGRES_HOST = os.getenv("POSTGRES_HOST", "localhost")
POSTGRES_PORT = os.getenv("POSTGRES_PORT", "5432")
POSTGRES_USER = os.getenv("POSTGRES_USER", "journal")
POSTGRES_PASSWORD = os.getenv("POSTGRES_PASSWORD")
POSTGRES_DB = os.getenv("POSTGRES_DB", "flowjournal")

# FastAPI app
app = FastAPI(title="Flow Journal API")
security = HTTPBasic()

# CORS middleware (adjust origins for production)
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Database connection pool
db_pool = None

@app.on_event("startup")
async def startup():
    global db_pool
    db_pool = await asyncpg.create_pool(
        host=POSTGRES_HOST,
        port=int(POSTGRES_PORT),
        user=POSTGRES_USER,
        password=POSTGRES_PASSWORD,
        database=POSTGRES_DB,
        min_size=2,
        max_size=10
    )

@app.on_event("shutdown")
async def shutdown():
    await db_pool.close()

# Pydantic models
class UserCreate(BaseModel):
    username: str
    password: str

class IntroReflection(BaseModel):
    q1_important_events: str
    q2_current_thoughts: str
    q3_physical_symptoms: str
    q4_current_feelings: str
    q5_brought_closer: str
    q6_brought_further: str
    q7_change_in_10_weeks: str

class DailyEntry(BaseModel):
    entry_date: date
    energy_level: Optional[int] = None
    selected_emotions: List[str] = []
    how_want_to_feel: Optional[str] = None
    daily_mantra: Optional[str] = None
    grateful_1: Optional[str] = None
    grateful_2: Optional[str] = None
    grateful_3: Optional[str] = None
    goal_1: Optional[str] = None
    goal_2: Optional[str] = None
    goal_3: Optional[str] = None
    selfcare_actions: Optional[str] = None
    free_journal: Optional[str] = None
    favorite_moment: Optional[str] = None

class WeeklyReflection(BaseModel):
    week_number: int
    week_start_date: date
    week_end_date: date
    current_mood: Optional[str] = None
    important_results: Optional[str] = None
    important_realizations: Optional[str] = None
    proud_1: Optional[str] = None
    proud_2: Optional[str] = None
    proud_3: Optional[str] = None
    proud_4: Optional[str] = None
    proud_5: Optional[str] = None
    change_phase: Optional[str] = None
    change_reflection: Optional[str] = None
    next_week_focus: Optional[str] = None
    task_1: Optional[str] = None
    task_2: Optional[str] = None
    task_3: Optional[str] = None
    task_4: Optional[str] = None
    task_5: Optional[str] = None

class FinalReflection(BaseModel):
    q1_starting_point: str
    q2_feeling_and_goal: str
    q3_journey_obstacles: str
    q4_arrival_changes: str
    q5_self_learning: str
    q6_future_path: str
    q7_journaling_impact: str
    q8_celebration: str

# Helper functions
def hash_password(password: str) -> str:
    return hashlib.sha256(password.encode()).hexdigest()

async def get_current_user(credentials: HTTPBasicCredentials = Depends(security)):
    username = credentials.username
    password_hash = hash_password(credentials.password)
    
    async with db_pool.acquire() as conn:
        user = await conn.fetchrow(
            "SELECT id, username, intro_completed FROM users WHERE username = $1 AND password_hash = $2",
            username, password_hash
        )
    
    if not user:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid credentials",
            headers={"WWW-Authenticate": "Basic"},
        )
    return dict(user)

# Auth endpoints
@app.post("/api/register")
async def register(user: UserCreate):
    password_hash = hash_password(user.password)
    
    try:
        async with db_pool.acquire() as conn:
            user_id = await conn.fetchval(
                "INSERT INTO users (username, password_hash) VALUES ($1, $2) RETURNING id",
                user.username, password_hash
            )
            
            # Create default settings
            await conn.execute(
                "INSERT INTO user_settings (user_id) VALUES ($1)",
                user_id
            )
            
        return {"message": "User created successfully", "user_id": user_id}
    except asyncpg.UniqueViolationError:
        raise HTTPException(status_code=400, detail="Username already exists")

@app.get("/api/user/status")
async def get_user_status(current_user: dict = Depends(get_current_user)):
    async with db_pool.acquire() as conn:
        user_data = await conn.fetchrow(
            "SELECT id, username, intro_completed, created_at FROM users WHERE id = $1",
            current_user["id"]
        )
    
    return {
        "user_id": user_data["id"],
        "username": user_data["username"],
        "intro_completed": user_data["intro_completed"],
        "created_at": user_data["created_at"].isoformat()
    }

# Intro reflection endpoints
@app.post("/api/intro-reflection")
async def save_intro_reflection(
    reflection: IntroReflection,
    current_user: dict = Depends(get_current_user)
):
    async with db_pool.acquire() as conn:
        await conn.execute("""
            INSERT INTO intro_reflection (
                user_id, q1_important_events, q2_current_thoughts, q3_physical_symptoms,
                q4_current_feelings, q5_brought_closer, q6_brought_further, q7_change_in_10_weeks
            ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8)
            ON CONFLICT (user_id) DO UPDATE SET
                q1_important_events = EXCLUDED.q1_important_events,
                q2_current_thoughts = EXCLUDED.q2_current_thoughts,
                q3_physical_symptoms = EXCLUDED.q3_physical_symptoms,
                q4_current_feelings = EXCLUDED.q4_current_feelings,
                q5_brought_closer = EXCLUDED.q5_brought_closer,
                q6_brought_further = EXCLUDED.q6_brought_further,
                q7_change_in_10_weeks = EXCLUDED.q7_change_in_10_weeks
        """, current_user["id"], reflection.q1_important_events, reflection.q2_current_thoughts,
             reflection.q3_physical_symptoms, reflection.q4_current_feelings,
             reflection.q5_brought_closer, reflection.q6_brought_further,
             reflection.q7_change_in_10_weeks)
        
        # Mark intro as completed
        await conn.execute(
            "UPDATE users SET intro_completed = TRUE WHERE id = $1",
            current_user["id"]
        )
    
    return {"message": "Intro reflection saved successfully"}

@app.get("/api/intro-reflection")
async def get_intro_reflection(current_user: dict = Depends(get_current_user)):
    async with db_pool.acquire() as conn:
        reflection = await conn.fetchrow(
            "SELECT * FROM intro_reflection WHERE user_id = $1",
            current_user["id"]
        )
    
    if not reflection:
        raise HTTPException(status_code=404, detail="Intro reflection not found")
    
    return dict(reflection)

# Daily entry endpoints
@app.post("/api/entries")
async def save_daily_entry(
    entry: DailyEntry,
    current_user: dict = Depends(get_current_user)
):
    async with db_pool.acquire() as conn:
        await conn.execute("""
            INSERT INTO daily_entries (
                user_id, entry_date, energy_level, selected_emotions, how_want_to_feel, daily_mantra,
                grateful_1, grateful_2, grateful_3, goal_1, goal_2, goal_3,
                selfcare_actions, free_journal, favorite_moment
            ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14, $15)
            ON CONFLICT (user_id, entry_date) DO UPDATE SET
                energy_level = EXCLUDED.energy_level,
                selected_emotions = EXCLUDED.selected_emotions,
                how_want_to_feel = EXCLUDED.how_want_to_feel,
                daily_mantra = EXCLUDED.daily_mantra,
                grateful_1 = EXCLUDED.grateful_1,
                grateful_2 = EXCLUDED.grateful_2,
                grateful_3 = EXCLUDED.grateful_3,
                goal_1 = EXCLUDED.goal_1,
                goal_2 = EXCLUDED.goal_2,
                goal_3 = EXCLUDED.goal_3,
                selfcare_actions = EXCLUDED.selfcare_actions,
                free_journal = EXCLUDED.free_journal,
                favorite_moment = EXCLUDED.favorite_moment,
                updated_at = NOW()
        """, current_user["id"], entry.entry_date, entry.energy_level, entry.selected_emotions,
             entry.how_want_to_feel, entry.daily_mantra,
             entry.grateful_1, entry.grateful_2, entry.grateful_3,
             entry.goal_1, entry.goal_2, entry.goal_3,
             entry.selfcare_actions, entry.free_journal, entry.favorite_moment)
    
    return {"message": "Entry saved successfully"}

@app.get("/api/entries/{entry_date}")
async def get_daily_entry(
    entry_date: date,
    current_user: dict = Depends(get_current_user)
):
    async with db_pool.acquire() as conn:
        entry = await conn.fetchrow(
            "SELECT * FROM daily_entries WHERE user_id = $1 AND entry_date = $2",
            current_user["id"], entry_date
        )
    
    if not entry:
        return None
    
    return dict(entry)

@app.get("/api/entries")
async def list_entries(
    limit: int = 30,
    current_user: dict = Depends(get_current_user)
):
    async with db_pool.acquire() as conn:
        entries = await conn.fetch(
            """SELECT entry_date, selected_emotions, created_at 
               FROM daily_entries 
               WHERE user_id = $1 
               ORDER BY entry_date DESC 
               LIMIT $2""",
            current_user["id"], limit
        )
    
    return [dict(e) for e in entries]

# Weekly reflection endpoints
@app.post("/api/weekly-reflection")
async def save_weekly_reflection(
    reflection: WeeklyReflection,
    current_user: dict = Depends(get_current_user)
):
    async with db_pool.acquire() as conn:
        await conn.execute("""
            INSERT INTO weekly_reflections (
                user_id, week_number, week_start_date, week_end_date,
                current_mood, important_results, important_realizations,
                proud_1, proud_2, proud_3, proud_4, proud_5,
                change_phase, change_reflection,
                next_week_focus, task_1, task_2, task_3, task_4, task_5
            ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14, $15, $16, $17, $18, $19, $20)
            ON CONFLICT (user_id, week_number) DO UPDATE SET
                current_mood = EXCLUDED.current_mood,
                important_results = EXCLUDED.important_results,
                important_realizations = EXCLUDED.important_realizations,
                proud_1 = EXCLUDED.proud_1,
                proud_2 = EXCLUDED.proud_2,
                proud_3 = EXCLUDED.proud_3,
                proud_4 = EXCLUDED.proud_4,
                proud_5 = EXCLUDED.proud_5,
                change_phase = EXCLUDED.change_phase,
                change_reflection = EXCLUDED.change_reflection,
                next_week_focus = EXCLUDED.next_week_focus,
                task_1 = EXCLUDED.task_1,
                task_2 = EXCLUDED.task_2,
                task_3 = EXCLUDED.task_3,
                task_4 = EXCLUDED.task_4,
                task_5 = EXCLUDED.task_5
        """, current_user["id"], reflection.week_number, reflection.week_start_date,
             reflection.week_end_date, reflection.current_mood, reflection.important_results,
             reflection.important_realizations, reflection.proud_1, reflection.proud_2,
             reflection.proud_3, reflection.proud_4, reflection.proud_5,
             reflection.change_phase, reflection.change_reflection,
             reflection.next_week_focus, reflection.task_1, reflection.task_2,
             reflection.task_3, reflection.task_4, reflection.task_5)
    
    return {"message": "Weekly reflection saved successfully"}

@app.get("/api/weekly-reflection/{week_number}")
async def get_weekly_reflection(
    week_number: int,
    current_user: dict = Depends(get_current_user)
):
    async with db_pool.acquire() as conn:
        reflection = await conn.fetchrow(
            "SELECT * FROM weekly_reflections WHERE user_id = $1 AND week_number = $2",
            current_user["id"], week_number
        )
    
    if not reflection:
        return None
    
    return dict(reflection)

@app.get("/api/weekly-reflections")
async def list_weekly_reflections(
    current_user: dict = Depends(get_current_user)
):
    async with db_pool.acquire() as conn:
        reflections = await conn.fetch(
            """SELECT * FROM weekly_reflections 
               WHERE user_id = $1 
               ORDER BY week_number DESC""",
            current_user["id"]
        )
    
    return [dict(r) for r in reflections]

# Final reflection endpoints
@app.post("/api/final-reflection")
async def save_final_reflection(
    reflection: FinalReflection,
    current_user: dict = Depends(get_current_user)
):
    async with db_pool.acquire() as conn:
        await conn.execute("""
            INSERT INTO final_reflection (
                user_id, q1_starting_point, q2_feeling_and_goal, q3_journey_obstacles,
                q4_arrival_changes, q5_self_learning, q6_future_path,
                q7_journaling_impact, q8_celebration
            ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9)
            ON CONFLICT (user_id) DO UPDATE SET
                q1_starting_point = EXCLUDED.q1_starting_point,
                q2_feeling_and_goal = EXCLUDED.q2_feeling_and_goal,
                q3_journey_obstacles = EXCLUDED.q3_journey_obstacles,
                q4_arrival_changes = EXCLUDED.q4_arrival_changes,
                q5_self_learning = EXCLUDED.q5_self_learning,
                q6_future_path = EXCLUDED.q6_future_path,
                q7_journaling_impact = EXCLUDED.q7_journaling_impact,
                q8_celebration = EXCLUDED.q8_celebration
        """, current_user["id"], reflection.q1_starting_point, reflection.q2_feeling_and_goal,
             reflection.q3_journey_obstacles, reflection.q4_arrival_changes,
             reflection.q5_self_learning, reflection.q6_future_path,
             reflection.q7_journaling_impact, reflection.q8_celebration)
    
    return {"message": "Final reflection saved successfully"}

@app.get("/api/final-reflection")
async def get_final_reflection(current_user: dict = Depends(get_current_user)):
    async with db_pool.acquire() as conn:
        reflection = await conn.fetchrow(
            "SELECT * FROM final_reflection WHERE user_id = $1",
            current_user["id"]
        )
    
    if not reflection:
        return None
    
    return dict(reflection)

# Emotion wheel settings
@app.get("/api/settings/emotion-wheel")
async def get_emotion_wheel(current_user: dict = Depends(get_current_user)):
    async with db_pool.acquire() as conn:
        settings = await conn.fetchrow(
            "SELECT emotion_wheel FROM user_settings WHERE user_id = $1",
            current_user["id"]
        )
    
    if not settings:
        raise HTTPException(status_code=404, detail="Settings not found")
    
    return settings["emotion_wheel"]

@app.put("/api/settings/emotion-wheel")
async def update_emotion_wheel(
    emotion_wheel: dict,
    current_user: dict = Depends(get_current_user)
):
    async with db_pool.acquire() as conn:
        await conn.execute(
            "UPDATE user_settings SET emotion_wheel = $1, updated_at = NOW() WHERE user_id = $2",
            emotion_wheel, current_user["id"]
        )
    
    return {"message": "Emotion wheel updated successfully"}

# Health check
@app.get("/health")
async def health_check():
    return {"status": "healthy"}