
import os
import sys

# Load .env file if present
_env_file = os.path.join(os.path.dirname(os.path.abspath(__file__)), ".env")
if os.path.exists(_env_file):
    try:
        with open(_env_file, "r", encoding="utf-8") as _ef:
            for _line in _ef:
                _line = _line.strip()
                if _line and not _line.startswith("#") and "=" in _line:
                    _k, _v = _line.split("=", 1)
                    os.environ.setdefault(_k.strip(), _v.strip())
    except Exception:
        pass


# ==================== UNIVERSAL STT & TRANSCRIPTION ENGINES ====================

GROQ_API_KEY = os.environ.get("GROQ_API_KEY", "")
OPENAI_API_KEY = os.environ.get("OPENAI_API_KEY", "")
WHISPER_BASE_URL = os.environ.get("WHISPER_BASE_URL", "https://api.groq.com/openai/v1/audio/transcriptions")
GLADIA_API_KEY = os.environ.get("GLADIA_API_KEY", "")
ASSEMBLYAI_API_KEY = os.environ.get("ASSEMBLYAI_API_KEY", "")
DEEPGRAM_API_KEY = os.environ.get("DEEPGRAM_API_KEY", "")

def transcribe_with_whisper_api(audio_bytes: bytes, base_url: str, api_key: str, model: str = "whisper-large-v3-turbo", target_lang: str = "ru", engine_name: str = "Groq Whisper"):
    """
    Universal OpenAI-compatible Whisper STT client.
    Supports Groq Whisper, OpenAI Whisper, or local self-hosted Faster-Whisper / whisper.cpp.
    """
    headers = {}
    if api_key and api_key.strip():
        headers["Authorization"] = f"Bearer {api_key.strip()}"

    files = {
        "file": ("lecture.m4a", audio_bytes, "audio/m4a")
    }
    data = {
        "model": model,
        "language": target_lang,
        "response_format": "verbose_json",
        "temperature": "0.0"
    }

    url = base_url.strip()
    if not url.endswith("/audio/transcriptions"):
        if url.endswith("/"):
            url += "audio/transcriptions"
        else:
            url += "/audio/transcriptions"

    res = requests.post(url, headers=headers, files=files, data=data, timeout=300)
    if res.status_code != 200:
        raise Exception(f"{engine_name} failed ({res.status_code}): {res.text[:200]}")

    result = res.json()
    full_text = result.get("text", "").strip()

    timed_segments = []
    raw_segments = result.get("segments", [])
    for s in raw_segments:
        s_start = float(s.get("start", 0.0))
        m = int(s_start // 60)
        sec = int(s_start % 60)
        time_str = f"{m:02d}:{sec:02d}"
        s_text = s.get("text", "").strip()
        if s_text:
            timed_segments.append({"start": s_start, "time": time_str, "text": s_text})

    return full_text, timed_segments, engine_name

ASSEMBLYAI_API_KEY = os.environ.get("ASSEMBLYAI_API_KEY", "")
DEEPGRAM_API_KEY = os.environ.get("DEEPGRAM_API_KEY", "")

def transcribe_with_gladia(audio_bytes: bytes, target_lang: str = "ru"):
    headers = {"x-gladia-key": GLADIA_API_KEY}
    files = {"audio": ("lecture.m4a", audio_bytes, "audio/m4a")}
    up_res = requests.post("https://api.gladia.io/v2/upload", headers=headers, files=files, timeout=90)
    if up_res.status_code != 200:
        raise Exception(f"Gladia upload failed: {up_res.status_code} - {up_res.text[:200]}")
    audio_url = up_res.json().get("audio_url")
    if not audio_url:
        raise Exception("Gladia didn't return audio_url")

    submit_payload = {
        "audio_url": audio_url,
        "audio_enhancer": True,
    }
    sub_res = requests.post("https://api.gladia.io/v2/pre-recorded", headers={"x-gladia-key": GLADIA_API_KEY, "Content-Type": "application/json"}, json=submit_payload, timeout=60)
    if sub_res.status_code not in (200, 201):
        raise Exception(f"Gladia submit failed: {sub_res.status_code} - {sub_res.text[:200]}")
    result_url = sub_res.json().get("result_url")
    if not result_url:
        raise Exception("Gladia didn't return result_url")

    for _ in range(75):
        time.sleep(2)
        r_poll = requests.get(result_url, headers={"x-gladia-key": GLADIA_API_KEY}, timeout=30)
        p_data = r_poll.json()
        status = p_data.get("status")
        if status == "done":
            res = p_data.get("result", {})
            transcription = res.get("transcription", {})
            full_text = transcription.get("full_transcript", "").strip()
            utterances = transcription.get("utterances", [])
            timed_segments = []
            for u in utterances:
                u_start = float(u.get("start", 0.0))
                m = int(u_start // 60)
                s = int(u_start % 60)
                time_str = f"{m:02d}:{s:02d}"
                u_text = u.get("text", "").strip()
                if u_text:
                    timed_segments.append({"start": u_start, "time": time_str, "text": u_text})
            return full_text, timed_segments, "Gladia AI (Audio Enhanced)"
        elif status == "error":
            raise Exception(f"Gladia transcription error: {p_data}")
    raise Exception("Gladia transcription timed out")

def transcribe_with_deepgram(audio_bytes: bytes, target_lang: str = "ru"):
    url = f"https://api.deepgram.com/v1/listen?model=nova-2&language={target_lang}&smart_format=true&punctuate=true&paragraphs=true&utterances=true&endpointing=false&filler_words=true"
    headers = {"Authorization": f"Token {DEEPGRAM_API_KEY}", "Content-Type": "audio/m4a"}
    res = requests.post(url, headers=headers, data=audio_bytes, timeout=300)
    if res.status_code != 200:
        raise Exception(f"Deepgram failed: {res.status_code} - {res.text[:200]}")
    dg_json = res.json()
    alt = dg_json["results"]["channels"][0]["alternatives"][0]
    paragraphs_data = alt.get("paragraphs", {}).get("paragraphs", [])
    raw_transcript = ""
    timed_segments = []
    if paragraphs_data:
        paras = []
        for p in paragraphs_data:
            p_start = float(p.get("start", 0.0))
            m = int(p_start // 60)
            s = int(p_start % 60)
            time_str = f"{m:02d}:{s:02d}"
            sentences = p.get("sentences", [])
            p_text = " ".join([s_item.get("text", "").strip() for s_item in sentences if s_item.get("text")])
            if p_text:
                paras.append(p_text)
                timed_segments.append({"start": p_start, "time": time_str, "text": p_text})
        if paras:
            raw_transcript = "\n\n".join(paras)
    if not raw_transcript:
        raw_transcript = alt.get("transcript", "")
    return raw_transcript.strip(), timed_segments, "Deepgram Nova-2"

def transcribe_with_assemblyai(audio_bytes: bytes, target_lang: str = "ru"):
    headers = {"authorization": ASSEMBLYAI_API_KEY}
    up_res = requests.post("https://api.assemblyai.com/v2/upload", headers=headers, data=audio_bytes, timeout=120)
    if up_res.status_code != 200:
        raise Exception(f"AssemblyAI upload failed: {up_res.status_code} - {up_res.text[:200]}")
    upload_url = up_res.json().get("upload_url")
    if not upload_url:
        raise Exception("AssemblyAI didn't return upload_url")

    sub_payload = {"audio_url": upload_url, "language_code": target_lang}
    sub_res = requests.post("https://api.assemblyai.com/v2/transcript", headers={"authorization": ASSEMBLYAI_API_KEY, "content-type": "application/json"}, json=sub_payload, timeout=60)
    if sub_res.status_code != 200:
        raise Exception(f"AssemblyAI submit failed: {sub_res.status_code} - {sub_res.text[:200]}")
    t_id = sub_res.json().get("id")
    if not t_id:
        raise Exception("AssemblyAI didn't return transcript id")

    for _ in range(75):
        time.sleep(2)
        r_poll = requests.get(f"https://api.assemblyai.com/v2/transcript/{t_id}", headers={"authorization": ASSEMBLYAI_API_KEY}, timeout=30)
        p_data = r_poll.json()
        status = p_data.get("status")
        if status == "completed":
            text = p_data.get("text", "").strip()
            words = p_data.get("words", [])
            timed_segments = []
            cur_seg = []
            cur_start = 0.0
            for w in words:
                w_text = w.get("text", "")
                if not cur_seg:
                    cur_start = float(w.get("start", 0)) / 1000.0
                cur_seg.append(w_text)
                if w_text.endswith((".", "?", "!")) or len(cur_seg) >= 20:
                    seg_text = " ".join(cur_seg)
                    m = int(cur_start // 60)
                    s = int(cur_start % 60)
                    time_str = f"{m:02d}:{s:02d}"
                    timed_segments.append({"start": cur_start, "time": time_str, "text": seg_text})
                    cur_seg = []
            if cur_seg:
                seg_text = " ".join(cur_seg)
                m = int(cur_start // 60)
                s = int(cur_start % 60)
                timed_segments.append({"start": cur_start, "time": f"{m:02d}:{s:02d}", "text": seg_text})
            return text, timed_segments, "AssemblyAI Universal"
        elif status == "error":
            raise Exception(f"AssemblyAI error: {p_data}")
    raise Exception("AssemblyAI transcription timed out")

import os
import sys
import time
import json
import re
import uuid
import datetime
import hashlib
from typing import Optional, List
from fastapi import FastAPI, Depends, HTTPException, status, UploadFile, File, Form, Query, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse, FileResponse
from pydantic import BaseModel, EmailStr
import pymysql
import jwt
import bcrypt
import requests
from a2wsgi import ASGIMiddleware

# Database configuration
DB_HOST = os.environ.get("DB_HOST", "localhost")
DB_USER = os.environ.get("DB_USER", "root")
DB_PASS = os.environ.get("DB_PASS", "")
DB_NAME = os.environ.get("DB_NAME", "libenet_db")

JWT_SECRET = os.environ.get("JWT_SECRET", "libenet_super_secret_jwt_key_2026_x7a91k")
JWT_ALGORITHM = "HS256"
JWT_EXPIRE_DAYS = 30

DEEPGRAM_API_KEY = os.environ.get("DEEPGRAM_API_KEY", "")
ORCAROUTER_API_KEY = os.environ.get("ORCAROUTER_API_KEY", "")
ORCAROUTER_MODEL = "deepseek/deepseek-v4-flash-free"

UPLOAD_DIR = os.path.join(os.path.dirname(os.path.abspath(__file__)), "uploads")
os.makedirs(UPLOAD_DIR, exist_ok=True)

def hash_password(password: str) -> str:
    pw_bytes = password.encode('utf-8')[:72]
    salt = bcrypt.gensalt(rounds=10)
    return bcrypt.hashpw(pw_bytes, salt).decode('utf-8')

def verify_password(password: str, hashed: str) -> bool:
    try:
        pw_bytes = password.encode('utf-8')[:72]
        return bcrypt.checkpw(pw_bytes, hashed.encode('utf-8'))
    except Exception:
        return False

def get_connection():
    return pymysql.connect(
        host=DB_HOST,
        user=DB_USER,
        password=DB_PASS,
        database=DB_NAME,
        charset='utf8mb4',
        cursorclass=pymysql.cursors.DictCursor,
        autocommit=True,
        connect_timeout=10,
        read_timeout=30,
        write_timeout=30
    )

def get_client_ip(request: Request) -> str:
    forwarded = request.headers.get("X-Forwarded-For")
    if forwarded:
        return forwarded.split(",")[0].strip()
    real_ip = request.headers.get("X-Real-IP")
    if real_ip:
        return real_ip.strip()
    if request.client:
        return request.client.host
    return "127.0.0.1"

def log_action(user_id: Optional[int], username: Optional[str], action: str, category: str, level: str, details: str, ip: str = ""):
    try:
        conn = get_connection()
        with conn.cursor() as cur:
            norm_level = level.upper() if level.upper() in ("INFO", "WARN", "ERROR") else "INFO"
            cur.execute("""
                INSERT INTO audit_logs (user_id, username, action, category, level, details, ip_address, created_at)
                VALUES (%s, %s, %s, %s, %s, %s, %s, %s)
            """, (user_id, username or "Аноним", action, category, norm_level, details, ip or "127.0.0.1", datetime.datetime.utcnow()))
        conn.close()
    except Exception as e:
        print(f"Ошибка записи лога: {e}")

def init_db():
    try:
        conn = get_connection()
        with conn.cursor() as cur:
            cur.execute("""
            CREATE TABLE IF NOT EXISTS users (
                id INT AUTO_INCREMENT PRIMARY KEY,
                username VARCHAR(64) UNIQUE NOT NULL,
                email VARCHAR(128) UNIQUE NOT NULL,
                password_hash VARCHAR(255) NOT NULL,
                role ENUM('user', 'admin') DEFAULT 'user',
                full_name VARCHAR(128) DEFAULT '',
                is_active BOOLEAN DEFAULT TRUE,
                created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
                last_login DATETIME NULL
            ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
            """)

            cur.execute("""
            CREATE TABLE IF NOT EXISTS lectures (
                id INT AUTO_INCREMENT PRIMARY KEY,
                user_id INT NOT NULL,
                title VARCHAR(255) NOT NULL,
                subject VARCHAR(128) DEFAULT '',
                teacher_name VARCHAR(128) DEFAULT '',
                duration_seconds INT DEFAULT 0,
                audio_filename VARCHAR(255) NULL,
                file_size_bytes BIGINT DEFAULT 0,
                status ENUM('recorded', 'transcribing', 'transcribed', 'summarizing', 'completed', 'error') DEFAULT 'recorded',
                error_message TEXT NULL,
                created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
                updated_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
                FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
            ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
            """)

            cur.execute("""
            CREATE TABLE IF NOT EXISTS lecture_data (
                id INT AUTO_INCREMENT PRIMARY KEY,
                lecture_id INT UNIQUE NOT NULL,
                raw_transcript LONGTEXT NULL,
                clean_summary LONGTEXT NULL,
                key_points JSON NULL,
                flashcards JSON NULL,
                timed_transcript LONGTEXT NULL,
                detected_language VARCHAR(32) DEFAULT 'ru',
                created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
                FOREIGN KEY (lecture_id) REFERENCES lectures(id) ON DELETE CASCADE
            ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
            """)

            try:
                cur.execute("ALTER TABLE lecture_data ADD COLUMN timed_transcript LONGTEXT NULL")
            except Exception:
                pass

            for _perm_col in ['can_transcribe', 'can_summarize', 'can_chat_general', 'can_chat_lecture']:
                try:
                    cur.execute(f"ALTER TABLE users ADD COLUMN {_perm_col} TINYINT(1) DEFAULT 1")
                except Exception:
                    pass

            cur.execute("""
            CREATE TABLE IF NOT EXISTS audit_logs (
                id INT AUTO_INCREMENT PRIMARY KEY,
                user_id INT NULL,
                username VARCHAR(64) NULL,
                action VARCHAR(128) NOT NULL,
                category VARCHAR(64) DEFAULT 'general',
                level ENUM('INFO', 'WARN', 'ERROR') DEFAULT 'INFO',
                details LONGTEXT NULL,
                ip_address VARCHAR(45) DEFAULT '',
                created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
                INDEX idx_created (created_at),
                INDEX idx_level (level)
            ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
            """)

            cur.execute("""
            CREATE TABLE IF NOT EXISTS system_settings (
                key_name VARCHAR(64) PRIMARY KEY,
                key_value LONGTEXT NULL,
                description VARCHAR(255) NULL,
                updated_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
            ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
            """)

            cur.execute("SELECT id FROM users WHERE username = 'admin'")
            admin = cur.fetchone()
            if not admin:
                admin_pass_hash = hash_password("admin123")
                cur.execute("""
                    INSERT INTO users (username, email, password_hash, role, full_name, is_active)
                    VALUES ('admin', 'admin@libenet.local', %s, 'admin', 'Администратор', TRUE)
                """, (admin_pass_hash,))
                log_action(1, "admin", "SYSTEM_INIT", "auth", "INFO", "Создан первичный аккаунт администратора: admin / admin123")

            cur.execute("""
                INSERT INTO system_settings (key_name, key_value, description)
                VALUES ('registration_enabled', 'true', 'Разрешена ли свободная регистрация пользователей')
                ON DUPLICATE KEY UPDATE key_name = key_name
            """)

            cur.execute("""
                INSERT INTO system_settings (key_name, key_value, description)
                VALUES ('deepgram_api_key', %s, 'Ключ Deepgram API для распознавания речи')
                ON DUPLICATE KEY UPDATE key_value = VALUES(key_value)
            """, (DEEPGRAM_API_KEY,))

            cur.execute("""
                INSERT INTO system_settings (key_name, key_value, description)
                VALUES ('orcarouter_api_key', %s, 'Ключ OrcaRouter API для DeepSeek V4 Flash')
                ON DUPLICATE KEY UPDATE key_value = VALUES(key_value)
            """, (ORCAROUTER_API_KEY,))

            cur.execute("""
                INSERT INTO system_settings (key_name, key_value, description)
                VALUES ('orcarouter_model', %s, 'Модель OrcaRouter для анализа конспекта')
                ON DUPLICATE KEY UPDATE key_value = VALUES(key_value)
            """, (ORCAROUTER_MODEL,))

        conn.close()
    except Exception as e:
        print(f"init_db error: {e}")

app = FastAPI(
    title="LibeNetLA API",
    version="1.6.0",
    description="Backend API with Deepgram Nova-2 RU & DeepSeek-V4-Flash via OrcaRouter"
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

@app.on_event("startup")
def on_startup():
    init_db()

class RegisterRequest(BaseModel):
    username: str
    email: str
    password: str
    full_name: Optional[str] = ""

class LoginRequest(BaseModel):
    username: str
    password: str

class AdminCreateUserRequest(BaseModel):
    username: str
    email: str
    password: str
    full_name: Optional[str] = ""
    role: str = "user"

class UserUpdateRequest(BaseModel):
    username: Optional[str] = None
    email: Optional[str] = None
    full_name: Optional[str] = None
    role: Optional[str] = None
    is_active: Optional[bool] = None
    password: Optional[str] = None
    can_transcribe: Optional[bool] = None
    can_summarize: Optional[bool] = None
    can_chat_general: Optional[bool] = None
    can_chat_lecture: Optional[bool] = None

class CreateLectureRequest(BaseModel):
    title: str
    subject: Optional[str] = ""
    teacher_name: Optional[str] = ""
    duration_seconds: Optional[int] = 0

class ClientLogRequest(BaseModel):
    action: str
    level: str = "INFO"
    details: str
    category: str = "client"

class SettingsUpdateRequest(BaseModel):
    registration_enabled: Optional[bool] = None
    deepgram_api_key: Optional[str] = None
    orcarouter_api_key: Optional[str] = None
    orcarouter_model: Optional[str] = None
    groq_api_key: Optional[str] = None
    openai_api_key: Optional[str] = None
    deepseek_api_key: Optional[str] = None
    openrouter_api_key: Optional[str] = None
    gladia_api_key: Optional[str] = None
    assemblyai_api_key: Optional[str] = None
    whisper_base_url: Optional[str] = None
    whisper_api_key: Optional[str] = None
    whisper_model: Optional[str] = None
    llm_provider: Optional[str] = None
    llm_base_url: Optional[str] = None
    llm_api_key: Optional[str] = None
    llm_model: Optional[str] = None

class LectureChatRequest(BaseModel):
    question: str
    history: Optional[List[dict]] = []

def create_access_token(user_id: int, username: str, role: str) -> str:
    payload = {
        "sub": str(user_id),
        "username": username,
        "role": role,
        "exp": datetime.datetime.utcnow() + datetime.timedelta(days=JWT_EXPIRE_DAYS)
    }
    return jwt.encode(payload, JWT_SECRET, algorithm=JWT_ALGORITHM)

def get_current_user(request: Request):
    auth_header = request.headers.get("Authorization")
    if not auth_header or not auth_header.startswith("Bearer "):
        raise HTTPException(status_code=401, detail="Требуется авторизация")
    token = auth_header.split(" ")[1]
    try:
        payload = jwt.decode(token, JWT_SECRET, algorithms=[JWT_ALGORITHM])
        user_id = int(payload["sub"])
        
        conn = get_connection()
        with conn.cursor() as cur:
            cur.execute("SELECT id, username, email, role, full_name, is_active, can_transcribe, can_summarize, can_chat_general, can_chat_lecture FROM users WHERE id = %s", (user_id,))
            user = cur.fetchone()
        conn.close()
        
        if not user or not user["is_active"]:
            raise HTTPException(status_code=401, detail="Пользователь не найден или заблокирован")
        user["can_transcribe"] = bool(user.get("can_transcribe", 1))
        user["can_summarize"] = bool(user.get("can_summarize", 1))
        user["can_chat_general"] = bool(user.get("can_chat_general", 1))
        user["can_chat_lecture"] = bool(user.get("can_chat_lecture", 1))
        return user
    except jwt.PyJWTError:
        raise HTTPException(status_code=401, detail="Неверный или просроченный токен авторизации")

def get_admin_user(current_user: dict = Depends(get_current_user)):
    if current_user["role"] != "admin":
        raise HTTPException(status_code=403, detail="Требуются права администратора")
    return current_user

# ==================== SYSTEM MONITORING & DIAGNOSTICS ====================

@app.get("/api/system/health-details")
def get_system_health_details(user: dict = Depends(get_current_user)):
    host_start = time.time()
    host_latency = round((time.time() - host_start) * 1000, 1)
    
    db_ok = False
    db_latency = 0.0
    try:
        db_t0 = time.time()
        conn = get_connection()
        with conn.cursor() as cur:
            cur.execute("SELECT 1 as ping")
            cur.fetchone()
        conn.close()
        db_latency = round((time.time() - db_t0) * 1000, 1)
        db_ok = True
    except Exception:
        pass

    dg_ok = False
    dg_latency = 0.0
    dg_key_status = "Не настроен"
    try:
        conn = get_connection()
        with conn.cursor() as cur:
            cur.execute("SELECT key_value FROM system_settings WHERE key_name = 'deepgram_api_key'")
            row = cur.fetchone()
            dg_key = (row["key_value"] if row and row["key_value"] else DEEPGRAM_API_KEY).strip()
        conn.close()

        if dg_key:
            dg_t0 = time.time()
            dg_res = requests.get(
                "https://api.deepgram.com/v1/projects",
                headers={"Authorization": f"Token {dg_key}"},
                timeout=5
            )
            dg_latency = round((time.time() - dg_t0) * 1000, 1)
            if dg_res.status_code == 200:
                dg_ok = True
                dg_key_status = "Активен (Nova-2 RU)"
            else:
                dg_key_status = f"Ошибка ({dg_res.status_code})"
    except Exception as e:
        dg_key_status = f"Таймаут ({str(e)[:25]})"

    # Test DeepSeek via OrcaRouter
    ds_ok = False
    ds_latency = 0.0
    ds_status = "Не настроен"
    try:
        conn = get_connection()
        with conn.cursor() as cur:
            cur.execute("SELECT key_value FROM system_settings WHERE key_name = 'orcarouter_api_key'")
            row = cur.fetchone()
            orca_k = (row["key_value"] if row and row["key_value"] else ORCAROUTER_API_KEY).strip()
        conn.close()

        if orca_k:
            ds_t0 = time.time()
            r_ds = requests.post(
                "https://api.orcarouter.ai/v1/chat/completions",
                headers={"Authorization": f"Bearer {orca_k}", "Content-Type": "application/json"},
                json={"model": ORCAROUTER_MODEL, "messages": [{"role": "user", "content": "ping"}], "max_tokens": 5},
                timeout=6
            )
            ds_latency = round((time.time() - ds_t0) * 1000, 1)
            if r_ds.status_code == 200:
                ds_ok = True
                ds_status = "Активен (LibeNet AI)"
            elif r_ds.status_code == 429:
                ds_status = "OrcaRouter: требуется привязать GitHub на сайте orcarouter.ai (429)"
            else:
                ds_status = f"Ошибка ({r_ds.status_code})"
    except Exception as e:
        ds_status = f"Таймаут ({str(e)[:25]})"

    return {
        "success": True,
        "timestamp": datetime.datetime.utcnow().isoformat(),
        "host": {
            "name": "AlwaysData Cloud",
            "url": "https://silenceteam.alwaysdata.net",
            "status": "online",
            "latency_ms": host_latency
        },
        "database": {
            "type": "MySQL 8.0 (InnoDB)",
            "host": "Internal (Protected)",
            "connected": db_ok,
            "latency_ms": db_latency
        },
        "deepgram": {
            "model": "Nova-2 (Russian Hardlocked)",
            "connected": dg_ok,
            "status": dg_key_status,
            "latency_ms": dg_latency
        },
        "neural_engine": {
            "status": ds_status,
            "connected": ds_ok,
            "latency_ms": ds_latency,
            "engine": "LibeNet Neural Engine (via OrcaRouter)",
            "model": ORCAROUTER_MODEL
        }
    }

# ==================== PUBLIC SETTINGS ====================

@app.get("/api/settings/public")
def get_public_settings():
    reg_enabled = True
    try:
        conn = get_connection()
        with conn.cursor() as cur:
            cur.execute("SELECT key_value FROM system_settings WHERE key_name = 'registration_enabled'")
            row = cur.fetchone()
            if row and row["key_value"]:
                reg_enabled = row["key_value"].strip().lower() in ("true", "1", "yes")
        conn.close()
    except Exception as e:
        print("Settings query error:", e)
    return {"success": True, "registration_enabled": reg_enabled}

# ==================== AUTH ====================

@app.post("/api/auth/register")
def register(req: RegisterRequest, request: Request):
    ip = get_client_ip(request)
    conn = get_connection()
    with conn.cursor() as cur:
        cur.execute("SELECT key_value FROM system_settings WHERE key_name = 'registration_enabled'")
        row = cur.fetchone()
        if row and row["key_value"] and row["key_value"].strip().lower() in ("false", "0", "no"):
            conn.close()
            log_action(None, req.username, "REGISTER_REJECTED", "auth", "WARN", f"Попытка регистрации при отключенной регистрации: {req.username}", ip)
            raise HTTPException(status_code=403, detail="Регистрация новых пользователей отключена администратором")

        if len(req.username) < 3 or len(req.password) < 4:
            conn.close()
            raise HTTPException(status_code=400, detail="Логин должен быть от 3 символов, пароль от 4 символов")
        
        cur.execute("SELECT id FROM users WHERE username = %s OR email = %s", (req.username, req.email))
        if cur.fetchone():
            conn.close()
            raise HTTPException(status_code=400, detail="Пользователь с таким логином или email уже существует")
        
        pwd_hash = hash_password(req.password)
        cur.execute("""
            INSERT INTO users (username, email, password_hash, role, full_name, is_active)
            VALUES (%s, %s, %s, 'user', %s, TRUE)
        """, (req.username, req.email, pwd_hash, req.full_name or ""))
        user_id = cur.lastrowid
    conn.close()
    
    log_action(user_id, req.username, "USER_REGISTER", "auth", "INFO", f"Успешная регистрация {req.username} ({req.email})", ip)
    token = create_access_token(user_id, req.username, "user")
    return {
        "success": True,
        "token": token,
        "user": {
            "id": user_id,
            "username": req.username,
            "email": req.email,
            "role": "user",
            "full_name": req.full_name or "",
            "can_transcribe": True,
            "can_summarize": True,
            "can_chat_general": True,
            "can_chat_lecture": True
        }
    }

@app.post("/api/auth/login")
def login(req: LoginRequest, request: Request):
    ip = get_client_ip(request)
    conn = get_connection()
    with conn.cursor() as cur:
        cur.execute("SELECT id, username, email, password_hash, role, full_name, is_active, can_transcribe, can_summarize, can_chat_general, can_chat_lecture FROM users WHERE username = %s OR email = %s", (req.username, req.username))
        user = cur.fetchone()
        
        if not user or not verify_password(req.password, user["password_hash"]):
            log_action(None, req.username, "LOGIN_FAILED", "auth", "WARN", f"Неудачная попытка входа: {req.username}", ip)
            conn.close()
            raise HTTPException(status_code=401, detail="Неверный логин или пароль")
        
        if not user["is_active"]:
            log_action(user["id"], user["username"], "LOGIN_BLOCKED", "auth", "WARN", f"Вход заблокированного аккаунта: {user['username']}", ip)
            conn.close()
            raise HTTPException(status_code=403, detail="Ваш аккаунт деактивирован администратором")
        
        cur.execute("UPDATE users SET last_login = %s WHERE id = %s", (datetime.datetime.utcnow(), user["id"]))
    conn.close()
    
    log_action(user["id"], user["username"], "LOGIN_SUCCESS", "auth", "INFO", f"Успешный вход пользователя {user['username']}", ip)
    token = create_access_token(user["id"], user["username"], user["role"])
    return {
        "success": True,
        "token": token,
        "user": {
            "id": user["id"],
            "username": user["username"],
            "email": user["email"],
            "role": user["role"],
            "full_name": user["full_name"] or "",
            "can_transcribe": bool(user.get("can_transcribe", 1)),
            "can_summarize": bool(user.get("can_summarize", 1)),
            "can_chat_general": bool(user.get("can_chat_general", 1)),
            "can_chat_lecture": bool(user.get("can_chat_lecture", 1))
        }
    }

@app.get("/api/auth/me")
def get_me(user: dict = Depends(get_current_user)):
    return {"success": True, "user": user}

# ==================== LECTURES ====================

@app.get("/api/lectures")
def get_lectures(user: dict = Depends(get_current_user)):
    conn = get_connection()
    with conn.cursor() as cur:
        if user["role"] == "admin":
            cur.execute("""
                SELECT l.*, u.username as owner_username, ld.detected_language,
                       (ld.raw_transcript IS NOT NULL AND LENGTH(ld.raw_transcript) > 0) as has_transcript,
                       (ld.clean_summary IS NOT NULL AND LENGTH(ld.clean_summary) > 0) as has_summary
                FROM lectures l
                LEFT JOIN users u ON l.user_id = u.id
                LEFT JOIN lecture_data ld ON l.id = ld.lecture_id
                ORDER BY l.created_at DESC
            """)
        else:
            cur.execute("""
                SELECT l.*, ld.detected_language,
                       (ld.raw_transcript IS NOT NULL AND LENGTH(ld.raw_transcript) > 0) as has_transcript,
                       (ld.clean_summary IS NOT NULL AND LENGTH(ld.clean_summary) > 0) as has_summary
                FROM lectures l
                LEFT JOIN lecture_data ld ON l.id = ld.lecture_id
                WHERE l.user_id = %s
                ORDER BY l.created_at DESC
            """, (user["id"],))
        lectures = cur.fetchall()
    conn.close()
    return {"success": True, "lectures": lectures}

@app.post("/api/lectures")
def create_lecture(req: CreateLectureRequest, user: dict = Depends(get_current_user), request: Request = None):
    ip = get_client_ip(request) if request else ""
    conn = get_connection()
    with conn.cursor() as cur:
        cur.execute("""
            INSERT INTO lectures (user_id, title, subject, teacher_name, duration_seconds, status)
            VALUES (%s, %s, %s, %s, %s, 'recorded')
        """, (user["id"], req.title, req.subject or "", req.teacher_name or "", req.duration_seconds or 0))
        lecture_id = cur.lastrowid
        cur.execute("INSERT INTO lecture_data (lecture_id) VALUES (%s)", (lecture_id,))
    conn.close()
    
    log_action(user["id"], user["username"], "CREATE_LECTURE", "lecture", "INFO", f"Создана лекция #{lecture_id}: {req.title}", ip)
    return {"success": True, "lecture_id": lecture_id, "message": "Лекция успешно создана"}

@app.get("/api/lectures/{lecture_id}")
def get_lecture_detail(lecture_id: int, user: dict = Depends(get_current_user)):
    conn = get_connection()
    with conn.cursor() as cur:
        cur.execute("""
            SELECT l.*, u.username as owner_username, ld.raw_transcript, ld.clean_summary, ld.key_points, ld.flashcards, ld.timed_transcript, ld.detected_language
            FROM lectures l
            LEFT JOIN users u ON l.user_id = u.id
            LEFT JOIN lecture_data ld ON l.id = ld.lecture_id
            WHERE l.id = %s
        """, (lecture_id,))
        lecture = cur.fetchone()
    conn.close()
    
    if not lecture:
        raise HTTPException(status_code=404, detail="Лекция не найдена")
    if user["role"] != "admin" and lecture["user_id"] != user["id"]:
        raise HTTPException(status_code=403, detail="Доступ запрещен")
    
    if isinstance(lecture.get("key_points"), str):
        try:
            lecture["key_points"] = json.loads(lecture["key_points"])
        except:
            lecture["key_points"] = []
    if isinstance(lecture.get("flashcards"), str):
        try:
            lecture["flashcards"] = json.loads(lecture["flashcards"])
        except:
            lecture["flashcards"] = []
    if isinstance(lecture.get("timed_transcript"), str):
        try:
            lecture["timed_transcript"] = json.loads(lecture["timed_transcript"])
        except:
            lecture["timed_transcript"] = []
            
    return {"success": True, "lecture": lecture}

@app.delete("/api/lectures/{lecture_id}")
def delete_lecture(lecture_id: int, user: dict = Depends(get_current_user), request: Request = None):
    ip = get_client_ip(request) if request else ""
    conn = get_connection()
    with conn.cursor() as cur:
        cur.execute("SELECT user_id, title, audio_filename FROM lectures WHERE id = %s", (lecture_id,))
        lecture = cur.fetchone()
        if not lecture:
            conn.close()
            raise HTTPException(status_code=404, detail="Лекция не найдена")
        if user["role"] != "admin" and lecture["user_id"] != user["id"]:
            conn.close()
            raise HTTPException(status_code=403, detail="Доступ запрещен")

        if not user.get("can_chat_lecture", True) and user.get("role") != "admin":
            conn.close()
            raise HTTPException(status_code=403, detail="Администратор ограничил доступ к чату по лекциям для вашего аккаунта")
        
        if lecture["audio_filename"]:
            path = os.path.join(UPLOAD_DIR, lecture["audio_filename"])
            if os.path.exists(path):
                try:
                    os.remove(path)
                except:
                    pass
        cur.execute("DELETE FROM lectures WHERE id = %s", (lecture_id,))
    conn.close()
    
    log_action(user["id"], user["username"], "DELETE_LECTURE", "lecture", "INFO", f"Удалена лекция #{lecture_id} ({lecture['title']})", ip)
    return {"success": True, "message": "Лекция удалена"}

@app.post("/api/lectures/{lecture_id}/upload-audio")
async def upload_audio(lecture_id: int, file: UploadFile = File(...), duration_seconds: int = Form(0), user: dict = Depends(get_current_user), request: Request = None):
    ip = get_client_ip(request) if request else ""
    conn = get_connection()
    with conn.cursor() as cur:
        cur.execute("SELECT user_id, title FROM lectures WHERE id = %s", (lecture_id,))
        lecture = cur.fetchone()
        if not lecture:
            conn.close()
            raise HTTPException(status_code=404, detail="Лекция не найдена")
        if user["role"] != "admin" and lecture["user_id"] != user["id"]:
            conn.close()
            raise HTTPException(status_code=403, detail="Доступ запрещен")
            
        ext = os.path.splitext(file.filename)[1] or ".m4a"
        filename = f"lecture_{lecture_id}_{uuid.uuid4().hex[:8]}{ext}"
        filepath = os.path.join(UPLOAD_DIR, filename)
        
        content = await file.read()
        file_size = len(content)
        if file_size == 0:
            conn.close()
            raise HTTPException(status_code=400, detail="Загружаемый аудиофайл пуст (0 байт)")
        with open(filepath, "wb") as f:
            f.write(content)
            
        cur.execute("""
            UPDATE lectures 
            SET audio_filename = %s, file_size_bytes = %s, duration_seconds = CASE WHEN %s > 0 THEN %s ELSE duration_seconds END, status = 'recorded'
            WHERE id = %s
        """, (filename, file_size, duration_seconds, duration_seconds, lecture_id))
    conn.close()
    
    log_action(user["id"], user["username"], "UPLOAD_AUDIO", "lecture", "INFO", f"Загружено аудио для лекции #{lecture_id} ({file_size / (1024*1024):.2f} MB)", ip)
    return {"success": True, "filename": filename, "file_size": file_size, "audio_url": f"/api/audio/{filename}"}

@app.get("/api/audio/{filename}")
def stream_audio(filename: str):
    safe_name = os.path.basename(filename)
    filepath = os.path.join(UPLOAD_DIR, safe_name)
    if not os.path.exists(filepath):
        raise HTTPException(status_code=404, detail="Аудиофайл не найден")
    ext = os.path.splitext(safe_name)[1].lower()
    mime_map = {
        ".m4a": "audio/mp4",
        ".mp3": "audio/mpeg",
        ".wav": "audio/wav",
        ".ogg": "audio/ogg",
        ".aac": "audio/aac",
        ".flac": "audio/flac",
    }
    media_type = mime_map.get(ext, "audio/mpeg")
    return FileResponse(filepath, media_type=media_type, headers={"Accept-Ranges": "bytes"})

# ==================== DEEPGRAM TRANSCRIPTION ====================

@app.post("/api/lectures/{lecture_id}/transcribe")
def transcribe_lecture(
    lecture_id: int,
    language: Optional[str] = "ru",
    engine: Optional[str] = "auto",
    user: dict = Depends(get_current_user),
    request: Request = None
):
    ip = get_client_ip(request) if request else ""
    conn = get_connection()
    with conn.cursor() as cur:
        cur.execute("SELECT * FROM lectures WHERE id = %s", (lecture_id,))
        lecture = cur.fetchone()
        if not lecture:
            conn.close()
            raise HTTPException(status_code=404, detail="Лекция не найдена")
        if user["role"] != "admin" and lecture["user_id"] != user["id"]:
            conn.close()
            raise HTTPException(status_code=403, detail="Доступ запрещен")

        if not user.get("can_transcribe", True) and user.get("role") != "admin":
            conn.close()
            raise HTTPException(status_code=403, detail="Администратор ограничил доступ к транскрибации для вашего аккаунта")

        if not lecture["audio_filename"]:
            conn.close()
            raise HTTPException(status_code=400, detail="Аудиозапись не загружена для данной лекции")

        audio_path = os.path.join(UPLOAD_DIR, lecture["audio_filename"])
        if not os.path.exists(audio_path):
            conn.close()
            raise HTTPException(status_code=404, detail="Аудиофайл не найден на сервере")

    with open(audio_path, "rb") as f:
        audio_bytes = f.read()

    target_lang = language or "ru"
    raw_transcript = ""
    timed_segments = []
    used_engine = ""
    errors = []

    # Engines order
    if engine == "gladia":
        engine_list = ["gladia"]
    elif engine == "deepgram":
        engine_list = ["deepgram"]
    elif engine == "assemblyai":
        engine_list = ["assemblyai"]
    else:
        # Default Auto: Gladia (best with enhancer) -> Deepgram -> AssemblyAI
        engine_list = ["gladia", "deepgram", "assemblyai"]

    for eng in engine_list:
        try:
            if eng == "groq":
                groq_k = os.environ.get("GROQ_API_KEY", "")
                if not groq_k:
                    continue
                raw_transcript, timed_segments, used_engine = transcribe_with_whisper_api(
                    audio_bytes, "https://api.groq.com/openai/v1", groq_k, "whisper-large-v3-turbo", target_lang, "Groq Whisper Large v3"
                )
            elif eng == "whisper":
                whisper_k = os.environ.get("OPENAI_API_KEY", "")
                whisper_url = os.environ.get("WHISPER_BASE_URL", "https://api.openai.com/v1")
                if not whisper_k and "localhost" not in whisper_url and "127.0.0.1" not in whisper_url:
                    continue
                raw_transcript, timed_segments, used_engine = transcribe_with_whisper_api(
                    audio_bytes, whisper_url, whisper_k, "whisper-1", target_lang, "OpenAI Whisper"
                )
            elif eng == "gladia":
                if not os.environ.get("GLADIA_API_KEY"):
                    continue
                raw_transcript, timed_segments, used_engine = transcribe_with_gladia(audio_bytes, target_lang)
            elif eng == "deepgram":
                if not os.environ.get("DEEPGRAM_API_KEY"):
                    continue
                raw_transcript, timed_segments, used_engine = transcribe_with_deepgram(audio_bytes, target_lang)
            elif eng == "assemblyai":
                if not os.environ.get("ASSEMBLYAI_API_KEY"):
                    continue
                raw_transcript, timed_segments, used_engine = transcribe_with_assemblyai(audio_bytes, target_lang)
            
            # If auto and transcript is too short (< 25 words on a > 60s file), try next engine
            if engine == "auto" and len(raw_transcript.split()) < 25 and (lecture.get("duration_seconds") or 0) > 60:
                errors.append(f"{used_engine}: Too few words ({len(raw_transcript.split())})")
                continue

            if raw_transcript:
                break
        except Exception as e:
            errors.append(f"{eng} error: {e}")

    if not raw_transcript:
        error_msg = f"Все сервисы транскрипции вернули ошибку: {'; '.join(errors)}"
        log_action(user["id"], user["username"], "TRANSCRIBE_FAIL", "ai", "ERROR", error_msg, ip)
        conn = get_connection()
        with conn.cursor() as cur:
            cur.execute("UPDATE lectures SET status = 'error', error_message = %s WHERE id = %s", (error_msg[:255], lecture_id))
        conn.close()
        raise HTTPException(status_code=500, detail=error_msg)

    # Save to database
    conn = get_connection()
    with conn.cursor() as cur:
        cur.execute("""
            INSERT INTO lecture_data (lecture_id, raw_transcript, timed_transcript, detected_language)
            VALUES (%s, %s, %s, %s)
            ON DUPLICATE KEY UPDATE raw_transcript = VALUES(raw_transcript), timed_transcript = VALUES(timed_transcript), detected_language = VALUES(detected_language)
        """, (lecture_id, raw_transcript, json.dumps(timed_segments, ensure_ascii=False), target_lang))

        cur.execute("UPDATE lectures SET status = 'transcribed', error_message = NULL WHERE id = %s", (lecture_id,))
    conn.close()

    log_action(user["id"], user["username"], "TRANSCRIBE_SUCCESS", "ai", "INFO", f"Лекция #{lecture_id} расшифрована через {used_engine} ({len(raw_transcript)} симв.)", ip)
    return {
        "success": True,
        "transcript": raw_transcript,
        "timed_transcript": timed_segments,
        "detected_language": target_lang,
        "engine": used_engine,
        "status": "transcribed"
    }


# ==================== DEEPSEEK-V4-FLASH AI SUMMARIZATION ====================


class SaveTranscriptRequest(BaseModel):
    raw_transcript: str
    timed_transcript: Optional[List[dict]] = []
    detected_language: Optional[str] = "ru"

@app.post("/api/lectures/{lecture_id}/save-transcript")
def save_lecture_transcript(lecture_id: int, req: SaveTranscriptRequest, user: dict = Depends(get_current_user), request: Request = None):
    ip = get_client_ip(request) if request else ""
    conn = get_connection()
    with conn.cursor() as cur:
        cur.execute("SELECT user_id, title FROM lectures WHERE id = %s", (lecture_id,))
        lec = cur.fetchone()
        if not lec:
            conn.close()
            raise HTTPException(status_code=404, detail="Лекция не найдена")
        if user["role"] != "admin" and lec["user_id"] != user["id"]:
            conn.close()
            raise HTTPException(status_code=403, detail="Доступ запрещен")

        cur.execute("""
            INSERT INTO lecture_data (lecture_id, raw_transcript, timed_transcript, detected_language)
            VALUES (%s, %s, %s, %s)
            ON DUPLICATE KEY UPDATE raw_transcript = VALUES(raw_transcript), timed_transcript = VALUES(timed_transcript), detected_language = VALUES(detected_language)
        """, (lecture_id, req.raw_transcript, json.dumps(req.timed_transcript or [], ensure_ascii=False), req.detected_language or "ru"))

        cur.execute("UPDATE lectures SET status = 'transcribed', error_message = NULL WHERE id = %s", (lecture_id,))
    conn.close()

    log_action(user["id"], user["username"], "SAVE_TRANSCRIPT", "ai", "INFO", f"Сохранена транскрипция для #{lecture_id} ({len(req.raw_transcript)} симв.)", ip)
    return {"success": True, "message": "Транскрипция сохранена", "status": "transcribed"}


# ==================== UNIVERSAL LLM ENGINE (MULTI-PROVIDER & LOCAL AI) ====================

# Default configuration from environment
LLM_PROVIDER = os.environ.get("LLM_PROVIDER", "auto") # auto, groq, deepseek, openai, openrouter, ollama, orcarouter, custom
LLM_BASE_URL = os.environ.get("LLM_BASE_URL", "").strip()
LLM_API_KEY = os.environ.get("LLM_API_KEY", "").strip()
LLM_MODEL = os.environ.get("LLM_MODEL", "").strip()

ORCAROUTER_API_KEY = os.environ.get("ORCAROUTER_API_KEY", "")
ORCAROUTER_MODEL = os.environ.get("ORCAROUTER_MODEL", "deepseek/deepseek-v4-flash-free")

LLM_PRESETS = {
    "groq": {
        "name": "Groq LLaMA 3.3 (High Speed)",
        "base_url": "https://api.groq.com/openai/v1/chat/completions",
        "default_model": "llama-3.3-70b-versatile",
        "env_key": "GROQ_API_KEY"
    },
    "deepseek": {
        "name": "DeepSeek Official",
        "base_url": "https://api.deepseek.com/v1/chat/completions",
        "default_model": "deepseek-chat",
        "env_key": "DEEPSEEK_API_KEY"
    },
    "openai": {
        "name": "OpenAI ChatGPT",
        "base_url": "https://api.openai.com/v1/chat/completions",
        "default_model": "gpt-4o-mini",
        "env_key": "OPENAI_API_KEY"
    },
    "openrouter": {
        "name": "OpenRouter Universal",
        "base_url": "https://openrouter.ai/api/v1/chat/completions",
        "default_model": "deepseek/deepseek-chat",
        "env_key": "OPENROUTER_API_KEY"
    },
    "ollama": {
        "name": "Ollama Local AI",
        "base_url": "http://localhost:11434/v1/chat/completions",
        "default_model": "llama3.2",
        "env_key": ""
    },
    "orcarouter": {
        "name": "OrcaRouter Gateway",
        "base_url": "https://api.orcarouter.ai/v1/chat/completions",
        "default_model": "deepseek/deepseek-v4-flash-free",
        "env_key": "ORCAROUTER_API_KEY"
    }
}

def get_configured_llm_candidates():
    """
    Builds an intelligent failover list of LLM endpoints:
    Tries primary configured -> secondary -> fallbacks.
    """
    # Load dynamic keys from DB if available
    db_settings = {}
    try:
        conn = get_connection()
        with conn.cursor() as cur:
            cur.execute("SELECT key_name, key_value FROM system_settings")
            rows = cur.fetchall()
            db_settings = {r["key_name"]: (r["key_value"] or "").strip() for r in rows}
        conn.close()
    except Exception:
        pass

    candidates = []

    # 1. Check custom LLM_BASE_URL
    custom_url = db_settings.get("llm_base_url") or LLM_BASE_URL
    custom_key = db_settings.get("llm_api_key") or LLM_API_KEY
    custom_model = db_settings.get("llm_model") or LLM_MODEL
    if custom_url:
        endpoint = custom_url
        if not endpoint.endswith("/chat/completions"):
            endpoint = endpoint.rstrip("/") + "/chat/completions"
        candidates.append({
            "name": "Custom Provider",
            "url": endpoint,
            "key": custom_key,
            "model": custom_model or "default"
        })

    # 2. Check Groq
    groq_k = db_settings.get("groq_api_key") or os.environ.get("GROQ_API_KEY", "")
    if groq_k:
        candidates.append({
            "name": "Groq LLaMA 3.3",
            "url": LLM_PRESETS["groq"]["base_url"],
            "key": groq_k,
            "model": db_settings.get("groq_model") or LLM_PRESETS["groq"]["default_model"]
        })

    # 3. Check DeepSeek Official
    deepseek_k = db_settings.get("deepseek_api_key") or os.environ.get("DEEPSEEK_API_KEY", "")
    if deepseek_k:
        candidates.append({
            "name": "DeepSeek Official",
            "url": LLM_PRESETS["deepseek"]["base_url"],
            "key": deepseek_k,
            "model": db_settings.get("deepseek_model") or LLM_PRESETS["deepseek"]["default_model"]
        })

    # 4. Check OpenRouter
    openrouter_k = db_settings.get("openrouter_api_key") or os.environ.get("OPENROUTER_API_KEY", "")
    if openrouter_k:
        candidates.append({
            "name": "OpenRouter",
            "url": LLM_PRESETS["openrouter"]["base_url"],
            "key": openrouter_k,
            "model": db_settings.get("openrouter_model") or LLM_PRESETS["openrouter"]["default_model"]
        })

    # 5. Check OpenAI
    openai_k = db_settings.get("openai_api_key") or os.environ.get("OPENAI_API_KEY", "")
    if openai_k:
        candidates.append({
            "name": "OpenAI",
            "url": LLM_PRESETS["openai"]["base_url"],
            "key": openai_k,
            "model": db_settings.get("openai_model") or LLM_PRESETS["openai"]["default_model"]
        })

    # 6. Check OrcaRouter
    orca_k = db_settings.get("orcarouter_api_key") or ORCAROUTER_API_KEY
    if orca_k:
        candidates.append({
            "name": "OrcaRouter",
            "url": LLM_PRESETS["orcarouter"]["base_url"],
            "key": orca_k,
            "model": db_settings.get("orcarouter_model") or ORCAROUTER_MODEL
        })

    # 7. Check local Ollama (only if explicitly requested or localhost)
    if custom_url and "11434" in custom_url:
        candidates.append({
            "name": "Ollama Local",
            "url": LLM_PRESETS["ollama"]["base_url"],
            "key": "",
            "model": custom_model or LLM_PRESETS["ollama"]["default_model"]
        })

    return candidates

def call_universal_llm(messages: list, temperature: float = 0.3, max_tokens: int = 3500, json_mode: bool = False) -> tuple[str, str]:
    """
    Executes an LLM chat completion with automatic failover across all configured providers.
    Returns: (content, provider_name)
    """
    candidates = get_configured_llm_candidates()
    if not candidates:
        raise Exception("Ни один AI-провайдер не настроен. Укажите API-ключ для Groq, DeepSeek, OpenAI, OpenRouter или OrcaRouter в настройках.")

    errors = []
    for cand in candidates:
        name = cand["name"]
        url = cand["url"]
        key = cand["key"]
        model = cand["model"]

        headers = {"Content-Type": "application/json"}
        if key:
            headers["Authorization"] = f"Bearer {key}"

        payload = {
            "model": model,
            "messages": messages,
            "temperature": temperature,
            "max_tokens": max_tokens
        }
        if json_mode:
            payload["response_format"] = {"type": "json_object"}

        try:
            res = requests.post(url, headers=headers, json=payload, timeout=60)
            if res.status_code == 200:
                data = res.json()
                content = data["choices"][0]["message"]["content"].strip()
                if content:
                    return content, f"{name} ({model})"
            else:
                errors.append(f"{name} returned {res.status_code}: {res.text[:120]}")
        except Exception as e:
            errors.append(f"{name} exception: {str(e)[:120]}")

    raise Exception(f"Все AI-провайдеры вернули ошибку: {'; '.join(errors)}")


@app.post("/api/lectures/{lecture_id}/summarize")
def summarize_lecture(lecture_id: int, user: dict = Depends(get_current_user), request: Request = None):
    ip = get_client_ip(request) if request else ""
    conn = get_connection()
    with conn.cursor() as cur:
        cur.execute("SELECT user_id, title, subject, teacher_name FROM lectures WHERE id = %s", (lecture_id,))
        lecture = cur.fetchone()
        if not lecture:
            conn.close()
            raise HTTPException(status_code=404, detail="Лекция не найдена")
        if user["role"] != "admin" and lecture["user_id"] != user["id"]:
            conn.close()
            raise HTTPException(status_code=403, detail="Доступ запрещен")
            
        if not user.get("can_summarize", True) and user.get("role") != "admin":
            conn.close()
            raise HTTPException(status_code=403, detail="Администратор ограничил доступ к генерации конспектов (ИИ) для вашего аккаунта")

        cur.execute("SELECT raw_transcript FROM lecture_data WHERE lecture_id = %s", (lecture_id,))
        ld = cur.fetchone()
        transcript = ld["raw_transcript"] if ld else None
        
        if not transcript or len(transcript.strip()) < 5:
            conn.close()
            raise HTTPException(status_code=400, detail="Сначала выполните транскрибацию аудиозаписи")
            
        cur.execute("SELECT key_value FROM system_settings WHERE key_name = 'orcarouter_api_key'")
        orca_row = cur.fetchone()
        orca_key = (orca_row["key_value"] if orca_row and orca_row["key_value"] else ORCAROUTER_API_KEY).strip()
        
        cur.execute("UPDATE lectures SET status = 'summarizing' WHERE id = %s", (lecture_id,))
    conn.close()
    
    log_action(user["id"], user["username"], "START_SUMMARIZE", "ai", "INFO", f"Запрос к LibeNet AI для лекции #{lecture_id}", ip)

    system_prompt = """Ты — ведущий университетский академический ассистент LibeNet Lecture Assistant.
Твоя задача — проанализировать полную расшифровку лекции (транскрипцию), полностью очистить её от «воды», слов-паразитов, оговорок и составить глубокий, исчерпывающий конспект.

КРИТИЧЕСКИЕ ПРАВИЛА ФИЛЬТРАЦИИ И АНАЛИЗА:
1. ИГНОРИРУЙ ЛИЧНЫЕ РАССКАЗЫ И ВОДУ: Если лектор в начале или середине лекции рассказывает о себе, своей биографии, студенческих годах, погоде или делает организационные объявления — ПОЛНОСТЬЮ ПРОПУСТИ ЭТО. Сосредоточься СТРОГО на научной теме предмета: определениях, классификациях, законах, формулах, функциях и терминах.
2. ОХВАТЫВАЙ ВСЮ ЛЕКЦИЮ: Конспект должен отражать весь материал пары — от первых научных определений до итоговых выводов преподавателя в конце. Не ограничивайся только началом!

КРИТИЧЕСКИ ВАЖНЫЕ ПРАВИЛА:
1. НЕ используй эмодзи (никаких смайликов).
2. НЕ добавляй раздел "практические выводы к зачету/экзамену".
3. Оформляй конспект в чистом, красивом Markdown:
   - Заголовки ##, ###, ####
   - Выделяй ключевые термины, формулы, правила и понятия **жирным шрифтом**.
   - Используй маркированные списки для перечислений.
4. ПРАВИЛО НЕУВЕРЕННОСТИ И СОМНИТЕЛЬНЫХ МЕСТ (ОЧЕНЬ ВАЖНО):
   Если в речи лектора встречаются неразборчивые фразы, сложные специфические термины, редкие фамилии, формулы или места, где смысл двусмысленен и ты не уверен на 100% в точности расшифровки:
   - НИ В КОЕМ СЛУЧАЕ НЕ ВЫРЕЗАЙ И НЕ УДАЛЯЙ этот фрагмент!
   - Обязательно сохрани контекст и пометь сомнительное место в тексте специальным маркером, например:
     `[Неразборчиво/Уточнить: <исходное слово или предполагаемый термин>]`
     или в скобках: `*(неразборчиво в аудио: возможно имелось в виду ...)*`.
   Студент должен видеть все спорные моменты лекции, чтобы переспросить у преподавателя.
5. В поле flashcards составь 4-6 глубоких интерактивных карточек (четкий вопрос и исчерпывающий ответ) по ключевым тезисам лекции.

Ответ СТРОГО верни в формате валидного JSON со следующей структурой:
{
  "clean_summary": "Текст структурированного конспекта в Markdown без эмодзи",
  "key_points": [
    "Главный тезис 1",
    "Главный тезис 2",
    "Главный тезис 3",
    "Главный тезис 4"
  ],
  "flashcards": [
    {"question": "Вопрос по материалу 1", "answer": "Подробный ответ 1"},
    {"question": "Вопрос по материалу 2", "answer": "Подробный ответ 2"}
  ]
}"""

    meta_info = f"Тема: {lecture['title']}"
    if lecture['subject']: meta_info += f", Предмет: {lecture['subject']}"
    if lecture['teacher_name']: meta_info += f", Преподаватель: {lecture['teacher_name']}"

    user_prompt = f"{meta_info}\n\nТранскрипция речи лекции:\n{transcript[:60000]}"

    clean_summary = ""
    key_points = []
    flashcards = []

    try:
        raw_text, used_ai_provider = call_universal_llm(
            messages=[
                {"role": "system", "content": system_prompt},
                {"role": "user", "content": user_prompt}
            ],
            temperature=0.25,
            max_tokens=4000
        )
        if raw_text:
            
            clean_json_str = raw_text
            if clean_json_str.startswith("```"):
                lines = clean_json_str.split("\n")
                if lines[0].startswith("```"):
                    lines = lines[1:]
                if lines and lines[-1].strip().startswith("```"):
                    lines = lines[:-1]
                clean_json_str = "\n".join(lines).strip()
            
            first_brace = clean_json_str.find("{")
            last_brace = clean_json_str.rfind("}")
            if first_brace != -1 and last_brace != -1 and last_brace > first_brace:
                clean_json_str = clean_json_str[first_brace:last_brace + 1]
                
            parsed = json.loads(clean_json_str)
            clean_summary = parsed.get("clean_summary", "")
            key_points = parsed.get("key_points", [])
            flashcards = parsed.get("flashcards", [])
        else:
            print(f"LibeNet AI response code: {r.status_code}, text: {r.text[:200]}")
    except Exception as e:
        print(f"LibeNet AI call exception: {e}")

    # Fallback if LLM request failed
    if not clean_summary or len(clean_summary.strip()) < 20:
        clean_summary = f"## {lecture['title']}\n\n"
        if lecture['subject']: clean_summary += f"**Предмет:** {lecture['subject']}\n\n"
        clean_summary += "### Главная суть материала\n"
        clean_summary += f"Материал посвящен теме **{lecture['title']}**.\n\n"
        clean_summary += "### Ключевые положения:\n"
        sentences = [s.strip() for s in re.split(r'(?<=[.?!])\s+', transcript) if len(s.strip()) > 20][:6]
        for idx, s in enumerate(sentences):
            clean_summary += f"{idx+1}. **{s[:50]}...** — {s[50:]}\n"
            key_points.append(s[:90])
            flashcards.append({"question": f"Что рассматривается в пункте {idx+1}?", "answer": s[:150]})

    conn = get_connection()
    with conn.cursor() as cur:
        cur.execute("""
            UPDATE lecture_data 
            SET clean_summary = %s, key_points = %s, flashcards = %s
            WHERE lecture_id = %s
        """, (clean_summary, json.dumps(key_points, ensure_ascii=False), json.dumps(flashcards, ensure_ascii=False), lecture_id))
        cur.execute("UPDATE lectures SET status = 'completed' WHERE id = %s", (lecture_id,))
    conn.close()
    
    log_action(user["id"], user["username"], "SUMMARIZE_SUCCESS", "ai", "INFO", f"LibeNet AI успешно сформировал конспект #{lecture_id}", ip)
    return {
        "success": True,
        "clean_summary": clean_summary,
        "key_points": key_points,
        "flashcards": flashcards,
        "status": "completed"
    }

# ==================== INTERACTIVE AI CHAT ====================

@app.post("/api/lectures/{lecture_id}/chat")
def chat_with_lecture(lecture_id: int, req: LectureChatRequest, user: dict = Depends(get_current_user), request: Request = None):
    ip = get_client_ip(request) if request else ""
    if not req.question or not req.question.strip():
        raise HTTPException(status_code=400, detail="Вопрос не может быть пустым")

    # Support general academic AI chat without binding to a specific lecture
    if lecture_id == 0:
        if not user.get("can_chat_general", True) and user.get("role") != "admin":
            raise HTTPException(status_code=403, detail="Администратор ограничил доступ к общему ИИ-ассистенту для вашего аккаунта")
        try:
            conn = get_connection()
            with conn.cursor() as cur:
                cur.execute("SELECT key_value FROM system_settings WHERE key_name = 'orcarouter_api_key'")
                row = cur.fetchone()
                o_key = (row["key_value"] if row and row["key_value"] else ORCAROUTER_API_KEY).strip()
            conn.close()

            sys_prompt = "Ты — академический AI-ассистент LibeNet. Отвечай студентам на русском языке развернуто, понятно, структурированно и с уважением. Помогай с темами лекций, подготовкой к экзаменам, сложными терминами, планами рефератов и формулами. Форматируй ответ в красивом Markdown со списками и жирными терминами."
            msgs = [{"role": "system", "content": sys_prompt}]
            for h in req.history[-6:]:
                if isinstance(h, dict) and "role" in h and "content" in h:
                    msgs.append({"role": h["role"], "content": h["content"]})
            msgs.append({"role": "user", "content": req.question.strip()})

            answer, used_prov = call_universal_llm(
                messages=msgs,
                temperature=0.4,
                max_tokens=1500
            )
            log_action(user["id"], user["username"], "GENERAL_AI_CHAT", "ai", "INFO", f"AI Чат ({used_prov}): {req.question[:50]}", ip)
            return {"success": True, "answer": answer, "provider": used_prov}
        except Exception as e:
            log_action(user["id"], user["username"], "AI_CHAT_ERROR", "ai", "ERROR", str(e), ip)
            raise HTTPException(status_code=500, detail=f"Ошибка AI чата: {e}")

    conn = get_connection()
    with conn.cursor() as cur:
        cur.execute("SELECT user_id, title, subject, teacher_name FROM lectures WHERE id = %s", (lecture_id,))
        lecture = cur.fetchone()
        if not lecture:
            conn.close()
            raise HTTPException(status_code=404, detail="Лекция не найдена")
        if user["role"] != "admin" and lecture["user_id"] != user["id"]:
            conn.close()
            raise HTTPException(status_code=403, detail="Доступ запрещен")

        cur.execute("SELECT clean_summary, raw_transcript FROM lecture_data WHERE lecture_id = %s", (lecture_id,))
        ld = cur.fetchone()
        cur.execute("SELECT key_value FROM system_settings WHERE key_name = 'orcarouter_api_key'")
        orca_row = cur.fetchone()
        orca_key = (orca_row["key_value"] if orca_row and orca_row["key_value"] else ORCAROUTER_API_KEY).strip()
    conn.close()

    summary = ld["clean_summary"] if ld and ld["clean_summary"] else ""
    transcript = ld["raw_transcript"] if ld and ld["raw_transcript"] else ""

    if not summary and not transcript:
        raise HTTPException(status_code=400, detail="Сначала выполните расшифровку или генерацию конспекта лекции")

    context_text = ""
    if summary:
        context_text += f"КОНСПЕКТ ЛЕКЦИИ:\n{summary[:25000]}\n\n"
    if transcript:
        context_text += f"ПОЛНЫЙ ТЕКСТ РЕЧИ ЛЕКТОРА:\n{transcript[:35000]}"

    sys_prompt = f"""Ты — академический AI-консультант и тьютор студента по лекции «{lecture['title']}».
Твоя задача — точно, понятно и профессионально отвечать на любые вопросы студента, опираясь на материалы лекции.

МАТЕРИАЛЫ ЛЕКЦИИ:
{context_text}

ПРАВИЛА ОТВЕТА:
1. Отвечай строго по существу вопроса на русском языке.
2. Опирайся на приведенные материалы лекции. Если лектор упоминал конкретную тему, формулу или тезис — сошлись на них.
3. Если студент просит объяснить простыми словами — объясни доступно на понятных аналогиях.
4. Оформляй ответ в красивом Markdown: выделяй термины **жирным шрифтом**, используй списки и формулы при необходимости.
5. НЕ используй смайлики и эмодзи. Отвечай как внимательный университетский преподаватель-наставник."""

    messages = [{"role": "system", "content": sys_prompt}]
    
    for h in req.history[-6:]:
        if isinstance(h, dict) and "role" in h and "content" in h:
            messages.append({"role": h["role"], "content": h["content"]})

    messages.append({"role": "user", "content": req.question.strip()})

    try:
        answer, used_prov = call_universal_llm(
            messages=messages,
            temperature=0.35,
            max_tokens=1500
        )
        log_action(user["id"], user["username"], "LECTURE_CHAT", "ai", "INFO", f"Вопрос по лекции #{lecture_id} ({used_prov}): {req.question[:60]}", ip)
        return {"success": True, "answer": answer, "provider": used_prov}
    except Exception as e:
        log_action(user["id"], user["username"], "LECTURE_CHAT_ERROR", "ai", "ERROR", str(e), ip)
        raise HTTPException(status_code=500, detail=f"Ошибка генерации ответа: {e}")

# ==================== ADMIN: USERS & LECTURES MANAGEMENT ====================

@app.get("/api/admin/settings")
def get_admin_settings(admin: dict = Depends(get_admin_user)):
    conn = get_connection()
    with conn.cursor() as cur:
        cur.execute("SELECT key_name, key_value, description FROM system_settings")
        rows = cur.fetchall()
    conn.close()
    settings = {}
    for r in rows:
        k_name = r["key_name"]
        k_val = r["key_value"] or ""
        settings[k_name] = k_val

    # Provide defaults from environment or standards if not set in DB
    if not settings.get("llm_base_url"):
        settings["llm_base_url"] = "https://api.orcarouter.ai/v1"
    if not settings.get("llm_model"):
        settings["llm_model"] = "deepseek/deepseek-v4-flash-free"
    if not settings.get("llm_api_key"):
        settings["llm_api_key"] = settings.get("orcarouter_api_key") or ORCAROUTER_API_KEY
    if not settings.get("orcarouter_api_key"):
        settings["orcarouter_api_key"] = settings.get("llm_api_key") or ORCAROUTER_API_KEY
    if not settings.get("deepgram_api_key") and DEEPGRAM_API_KEY:
        settings["deepgram_api_key"] = DEEPGRAM_API_KEY
    if not settings.get("gladia_api_key") and os.environ.get("GLADIA_API_KEY"):
        settings["gladia_api_key"] = os.environ.get("GLADIA_API_KEY")
    if not settings.get("assemblyai_api_key") and os.environ.get("ASSEMBLYAI_API_KEY"):
        settings["assemblyai_api_key"] = os.environ.get("ASSEMBLYAI_API_KEY")

    return {"success": True, "settings": settings}

@app.post("/api/admin/settings")
def update_admin_settings(req: SettingsUpdateRequest, admin: dict = Depends(get_admin_user), request: Request = None):
    ip = get_client_ip(request) if request else ""
    conn = get_connection()
    with conn.cursor() as cur:
        if req.registration_enabled is not None:
            val = "true" if req.registration_enabled else "false"
            cur.execute("""
                INSERT INTO system_settings (key_name, key_value, description)
                VALUES ('registration_enabled', %s, 'Разрешена ли свободная регистрация')
                ON DUPLICATE KEY UPDATE key_value = VALUES(key_value)
            """, (val,))
            log_action(admin["id"], admin["username"], "UPDATE_SETTING", "admin", "WARN", f"Регистрация установлена в: {val}", ip)
            
        if req.deepgram_api_key is not None and "..." not in req.deepgram_api_key and "***" not in req.deepgram_api_key:
            cur.execute("""
                INSERT INTO system_settings (key_name, key_value, description)
                VALUES ('deepgram_api_key', %s, 'Ключ Deepgram API')
                ON DUPLICATE KEY UPDATE key_value = VALUES(key_value)
            """, (req.deepgram_api_key.strip(),))
            log_action(admin["id"], admin["username"], "UPDATE_SETTING", "admin", "WARN", "Обновлен ключ Deepgram API", ip)

        if req.orcarouter_api_key is not None and "..." not in req.orcarouter_api_key and "***" not in req.orcarouter_api_key:
            cur.execute("""
                INSERT INTO system_settings (key_name, key_value, description)
                VALUES ('orcarouter_api_key', %s, 'Ключ OrcaRouter API')
                ON DUPLICATE KEY UPDATE key_value = VALUES(key_value)
            """, (req.orcarouter_api_key.strip(),))

        extra_fields = [
            ("groq_api_key", req.groq_api_key, "Ключ Groq API"),
            ("openai_api_key", req.openai_api_key, "Ключ OpenAI API"),
            ("deepseek_api_key", req.deepseek_api_key, "Ключ DeepSeek API"),
            ("openrouter_api_key", req.openrouter_api_key, "Ключ OpenRouter API"),
            ("gladia_api_key", req.gladia_api_key, "Ключ Gladia API"),
            ("assemblyai_api_key", req.assemblyai_api_key, "Ключ AssemblyAI API"),
            ("orcarouter_model", req.orcarouter_model, "Модель OrcaRouter"),
            ("whisper_base_url", req.whisper_base_url, "Кастомный эндпоинт Whisper STT"),
            ("whisper_api_key", req.whisper_api_key, "API ключ Whisper STT"),
            ("whisper_model", req.whisper_model, "Модель Whisper"),
            ("llm_provider", req.llm_provider, "Активный LLM провайдер"),
            ("llm_base_url", req.llm_base_url, "Базовый URL LLM провайдера"),
            ("llm_api_key", req.llm_api_key, "API ключ универсального LLM"),
            ("llm_model", req.llm_model, "Модель LLM"),
        ]
        for key_name, val, desc in extra_fields:
            if val is not None:
                cleaned_val = val.strip()
                if "key" in key_name.lower() or "secret" in key_name.lower() or "token" in key_name.lower():
                    if "..." in cleaned_val or "***" in cleaned_val:
                        continue # Do not overwrite real secret with masked placeholder
                cur.execute("""
                    INSERT INTO system_settings (key_name, key_value, description)
                    VALUES (%s, %s, %s)
                    ON DUPLICATE KEY UPDATE key_value = VALUES(key_value)
                """, (key_name, cleaned_val, desc))
                log_action(admin["id"], admin["username"], "UPDATE_SETTING", "admin", "WARN", f"Обновлена настройка {key_name}", ip)
                
                # Keep orcarouter_api_key in sync if universal llm_api_key was updated
                if key_name == "llm_api_key" and cleaned_val:
                    cur.execute("""
                        INSERT INTO system_settings (key_name, key_value, description)
                        VALUES ('orcarouter_api_key', %s, 'Ключ OrcaRouter API')
                        ON DUPLICATE KEY UPDATE key_value = VALUES(key_value)
                    """, (cleaned_val,))
    conn.close()
    return {"success": True, "message": "Настройки сохранены"}

@app.post("/api/admin/users")
def admin_create_user(req: AdminCreateUserRequest, admin: dict = Depends(get_admin_user), request: Request = None):
    ip = get_client_ip(request) if request else ""
    if len(req.username) < 3 or len(req.password) < 4:
        raise HTTPException(status_code=400, detail="Логин от 3 символов, пароль от 4 символов")
    
    conn = get_connection()
    with conn.cursor() as cur:
        cur.execute("SELECT id FROM users WHERE username = %s OR email = %s", (req.username, req.email))
        if cur.fetchone():
            conn.close()
            raise HTTPException(status_code=400, detail="Пользователь с таким логином или email уже существует")
        
        pwd_hash = hash_password(req.password)
        role = req.role if req.role in ("user", "admin") else "user"
        cur.execute("""
            INSERT INTO users (username, email, password_hash, role, full_name, is_active)
            VALUES (%s, %s, %s, %s, %s, TRUE)
        """, (req.username, req.email, pwd_hash, role, req.full_name or ""))
        new_id = cur.lastrowid
    conn.close()
    
    log_action(admin["id"], admin["username"], "ADMIN_CREATE_USER", "admin", "INFO", f"Администратор создал пользователя #{new_id} ({req.username}, роль: {role})", ip)
    return {"success": True, "message": f"Пользователь {req.username} успешно создан", "user_id": new_id}

@app.get("/api/admin/stats")
def get_admin_stats(admin: dict = Depends(get_admin_user)):
    conn = get_connection()
    with conn.cursor() as cur:
        cur.execute("SELECT COUNT(*) as total_users, SUM(is_active) as active_users FROM users")
        u_stats = cur.fetchone()
        
        cur.execute("SELECT COUNT(*) as total_lectures, SUM(duration_seconds) as total_duration, SUM(file_size_bytes) as total_storage FROM lectures")
        l_stats = cur.fetchone()
        
        cur.execute("SELECT COUNT(*) as total_logs, SUM(level = 'ERROR') as error_logs, SUM(level = 'WARN') as warn_logs FROM audit_logs")
        log_stats = cur.fetchone()
    conn.close()
    
    return {
        "success": True,
        "stats": {
            "total_users": u_stats["total_users"] or 0,
            "active_users": u_stats["active_users"] or 0,
            "total_lectures": l_stats["total_lectures"] or 0,
            "total_duration_minutes": round((l_stats["total_duration"] or 0) / 60, 1),
            "total_storage_mb": round((l_stats["total_storage"] or 0) / (1024 * 1024), 2),
            "total_logs": log_stats["total_logs"] or 0,
            "error_logs": log_stats["error_logs"] or 0,
            "warn_logs": log_stats.get("warn_logs", 0) or 0,
        }
    }

@app.get("/api/admin/users")
def list_admin_users(search: Optional[str] = None, admin: dict = Depends(get_admin_user)):
    conn = get_connection()
    with conn.cursor() as cur:
        query = """
            SELECT u.id, u.username, u.email, u.role, u.full_name, u.is_active, u.created_at, u.last_login,
                   u.can_transcribe, u.can_summarize, u.can_chat_general, u.can_chat_lecture,
                   COUNT(l.id) as lectures_count
            FROM users u
            LEFT JOIN lectures l ON u.id = l.user_id
        """
        params = []
        if search:
            query += " WHERE u.username LIKE %s OR u.email LIKE %s OR u.full_name LIKE %s "
            like_s = f"%{search}%"
            params.extend([like_s, like_s, like_s])
        query += " GROUP BY u.id ORDER BY u.id DESC"
        cur.execute(query, tuple(params))
        users = cur.fetchall()
        for u in users:
            u["can_transcribe"] = bool(u.get("can_transcribe", 1))
            u["can_summarize"] = bool(u.get("can_summarize", 1))
            u["can_chat_general"] = bool(u.get("can_chat_general", 1))
            u["can_chat_lecture"] = bool(u.get("can_chat_lecture", 1))
    conn.close()
    return {"success": True, "users": users}

@app.put("/api/admin/users/{user_id}")
def update_user(user_id: int, req: UserUpdateRequest, admin: dict = Depends(get_admin_user), request: Request = None):
    ip = get_client_ip(request) if request else ""
    conn = get_connection()
    with conn.cursor() as cur:
        cur.execute("SELECT id, username, role FROM users WHERE id = %s", (user_id,))
        target_user = cur.fetchone()
        if not target_user:
            conn.close()
            raise HTTPException(status_code=404, detail="Пользователь не найден")
            
        updates = []
        params = []
        if req.username is not None and req.username.strip():
            cur.execute("SELECT id FROM users WHERE username = %s AND id != %s", (req.username.strip(), user_id))
            if cur.fetchone():
                conn.close()
                raise HTTPException(status_code=400, detail="Этот логин уже занят другим пользователем")
            updates.append("username = %s")
            params.append(req.username.strip())
            
        if req.email is not None and req.email.strip():
            cur.execute("SELECT id FROM users WHERE email = %s AND id != %s", (req.email.strip(), user_id))
            if cur.fetchone():
                conn.close()
                raise HTTPException(status_code=400, detail="Этот email уже занят")
            updates.append("email = %s")
            params.append(req.email.strip())
            
        if req.full_name is not None:
            updates.append("full_name = %s")
            params.append(req.full_name)
        if req.role is not None and req.role in ("user", "admin"):
            updates.append("role = %s")
            params.append(req.role)
        if req.is_active is not None:
            updates.append("is_active = %s")
            params.append(req.is_active)
        if req.password and len(req.password) >= 4:
            updates.append("password_hash = %s")
            params.append(hash_password(req.password))
        if req.can_transcribe is not None:
            updates.append("can_transcribe = %s")
            params.append(1 if req.can_transcribe else 0)
        if req.can_summarize is not None:
            updates.append("can_summarize = %s")
            params.append(1 if req.can_summarize else 0)
        if req.can_chat_general is not None:
            updates.append("can_chat_general = %s")
            params.append(1 if req.can_chat_general else 0)
        if req.can_chat_lecture is not None:
            updates.append("can_chat_lecture = %s")
            params.append(1 if req.can_chat_lecture else 0)
            
        if updates:
            params.append(user_id)
            sql = f"UPDATE users SET {', '.join(updates)} WHERE id = %s"
            cur.execute(sql, tuple(params))
    conn.close()
    
    log_action(admin["id"], admin["username"], "ADMIN_UPDATE_USER", "admin", "INFO", f"Администратор обновил данные пользователя #{user_id} ({target_user['username']})", ip)
    return {"success": True, "message": "Данные пользователя успешно обновлены"}

@app.delete("/api/admin/users/{user_id}")
def delete_user(user_id: int, admin: dict = Depends(get_admin_user), request: Request = None):
    ip = get_client_ip(request) if request else ""
    if user_id == admin["id"]:
        raise HTTPException(status_code=400, detail="Нельзя удалить свой собственный аккаунт администратора")
        
    conn = get_connection()
    with conn.cursor() as cur:
        cur.execute("SELECT username FROM users WHERE id = %s", (user_id,))
        u = cur.fetchone()
        if not u:
            conn.close()
            raise HTTPException(status_code=404, detail="Пользователь не найден")
        cur.execute("SELECT audio_filename FROM lectures WHERE user_id = %s AND audio_filename IS NOT NULL", (user_id,))
        user_audios = cur.fetchall()
        for a_row in user_audios:
            if a_row.get("audio_filename"):
                try:
                    fpath = os.path.join(UPLOAD_DIR, a_row["audio_filename"])
                    if os.path.exists(fpath):
                        os.remove(fpath)
                except Exception:
                    pass
        cur.execute("DELETE FROM users WHERE id = %s", (user_id,))
    conn.close()
    
    log_action(admin["id"], admin["username"], "ADMIN_DELETE_USER", "admin", "WARN", f"Удален пользователь #{user_id} ({u['username']})", ip)
    return {"success": True, "message": f"Пользователь {u['username']} удален"}

@app.get("/api/admin/lectures")
def list_admin_lectures(search: Optional[str] = None, admin: dict = Depends(get_admin_user)):
    conn = get_connection()
    with conn.cursor() as cur:
        query = """
            SELECT l.*, u.username as owner_username, u.email as owner_email,
                   (ld.raw_transcript IS NOT NULL AND LENGTH(ld.raw_transcript) > 0) as has_transcript,
                   (ld.clean_summary IS NOT NULL AND LENGTH(ld.clean_summary) > 0) as has_summary
            FROM lectures l
            LEFT JOIN users u ON l.user_id = u.id
            LEFT JOIN lecture_data ld ON l.id = ld.lecture_id
        """
        params = []
        if search:
            query += " WHERE l.title LIKE %s OR u.username LIKE %s OR l.subject LIKE %s "
            like_s = f"%{search}%"
            params.extend([like_s, like_s, like_s])
        query += " ORDER BY l.id DESC"
        cur.execute(query, tuple(params))
        lectures = cur.fetchall()
    conn.close()
    return {"success": True, "lectures": lectures}

@app.delete("/api/admin/lectures/{lecture_id}")
def admin_delete_lecture(lecture_id: int, admin: dict = Depends(get_admin_user), request: Request = None):
    ip = get_client_ip(request) if request else ""
    conn = get_connection()
    with conn.cursor() as cur:
        cur.execute("SELECT title, audio_filename FROM lectures WHERE id = %s", (lecture_id,))
        lec = cur.fetchone()
        if not lec:
            conn.close()
            raise HTTPException(status_code=404, detail="Лекция не найдена")
            
        if lec["audio_filename"]:
            path = os.path.join(UPLOAD_DIR, lec["audio_filename"])
            if os.path.exists(path):
                try:
                    os.remove(path)
                except Exception as e:
                    print(f"Error removing audio file {path}: {e}")
                    
        cur.execute("DELETE FROM lectures WHERE id = %s", (lecture_id,))
    conn.close()
    
    log_action(admin["id"], admin["username"], "ADMIN_DELETE_LECTURE", "admin", "WARN", f"Администратор навсегда удалил лекцию #{lecture_id} («{lec['title']}»)", ip)
    return {"success": True, "message": f"Лекция #{lecture_id} («{lec['title']}») полностью удалена с сервера"}

@app.get("/api/admin/logs")
def get_admin_logs(
    level: Optional[str] = None,
    category: Optional[str] = None,
    search: Optional[str] = None,
    limit: int = 150,
    offset: int = 0,
    admin: dict = Depends(get_admin_user)
):
    conn = get_connection()
    with conn.cursor() as cur:
        query = "SELECT * FROM audit_logs WHERE 1=1"
        params = []
        if level and level.upper() != "ALL":
            query += " AND level = %s"
            params.append(level.upper())
        if category and category != "all":
            query += " AND category = %s"
            params.append(category)
        if search:
            query += " AND (action LIKE %s OR details LIKE %s OR username LIKE %s OR ip_address LIKE %s)"
            like_s = f"%{search}%"
            params.extend([like_s, like_s, like_s, like_s])
            
        query += " ORDER BY id DESC LIMIT %s OFFSET %s"
        params.extend([limit, offset])
        
        cur.execute(query, tuple(params))
        logs = cur.fetchall()
    conn.close()
    return {"success": True, "logs": logs, "count": len(logs)}

@app.delete("/api/admin/logs/clear")
def clear_admin_logs(admin: dict = Depends(get_admin_user), request: Request = None):
    ip = get_client_ip(request) if request else ""
    conn = get_connection()
    with conn.cursor() as cur:
        cur.execute("TRUNCATE TABLE audit_logs")
    conn.close()
    
    log_action(admin["id"], admin["username"], "CLEAR_LOGS", "admin", "WARN", "Логи очищены администратором", ip)
    return {"success": True, "message": "Логи очищены"}

# ==================== CLIENT LOGS & HEALTH ====================

@app.post("/api/logs/client")
def receive_client_log(req: ClientLogRequest, request: Request):
    ip = get_client_ip(request)
    log_action(None, "MobileClient", req.action, req.category, req.level.upper(), req.details, ip)
    return {"success": True}

@app.get("/api/health")
def health_check():
    return {
        "status": "online",
        "service": "LibeNetLA API",
        "timestamp": datetime.datetime.utcnow().isoformat(),
        "deepgram_configured": bool(DEEPGRAM_API_KEY),
        "deepseek_configured": bool(ORCAROUTER_API_KEY)
    }

application = ASGIMiddleware(app)
