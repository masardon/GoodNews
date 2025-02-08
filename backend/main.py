from fastapi import FastAPI, HTTPException, Depends, Header
from pydantic import BaseModel
from datetime import datetime, timedelta
import json
import os
import bcrypt
import jwt
from dotenv import load_dotenv

# Path untuk kredensial admin
env_path = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "creds/.secrets.env"))
load_dotenv(env_path)

ADMIN_USER_ID = os.getenv("ADMIN_USER_ID")
ADMIN_PASSWORD_HASH = os.getenv("ADMIN_PASSWORD")

SECRET_KEY = "supersecretkey"
ALGORITHM = "HS256"
TOKEN_EXPIRATION_MINUTES = 60

app = FastAPI()

# Path untuk menyimpan database
DB_FILE = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "data/articles_db.json"))

# Model untuk artikel
class Article(BaseModel):
    id: str
    title: str
    url: str
    status: str
    publish_at: datetime
    unpublish_at: datetime

class CreateArticleRequest(BaseModel):
    title: str
    url: str
    status: str
    publish_at: datetime = None

class UpdateArticleRequest(BaseModel):
    title: str = None
    url: str = None
    status: str = None
    publish_at: datetime = None

class LoginRequest(BaseModel):
    username: str
    password: str

# Fungsi membaca database
def load_articles():
    if not os.path.exists(DB_FILE):
        return []
    with open(DB_FILE, "r") as f:
        return json.load(f)

# Fungsi menyimpan database
def save_articles(articles):
    with open(DB_FILE, "w") as f:
        json.dump(articles, f, indent=4)

# Fungsi membuat JWT token
def create_token(username: str):
    expiration = datetime.utcnow() + timedelta(minutes=TOKEN_EXPIRATION_MINUTES)
    payload = {"sub": username, "exp": expiration}
    return jwt.encode(payload, SECRET_KEY, algorithm=ALGORITHM)

# Middleware untuk verifikasi admin
def verify_admin(username: str, password: str):
    if username != ADMIN_USER_ID or not bcrypt.checkpw(password.encode(), ADMIN_PASSWORD_HASH.encode()):
        raise HTTPException(status_code=401, detail="Invalid credentials")
    return True

# Middleware untuk autentikasi token
def get_current_admin(authorization: str = Header(None)):
    if not authorization or not authorization.startswith("Bearer "):
        raise HTTPException(status_code=401, detail="Missing token")

    token = authorization.split(" ")[1]
    try:
        payload = jwt.decode(token, SECRET_KEY, algorithms=[ALGORITHM])
        return payload["sub"]
    except jwt.ExpiredSignatureError:
        raise HTTPException(status_code=401, detail="Token expired")
    except jwt.InvalidTokenError:
        raise HTTPException(status_code=401, detail="Invalid token")

# Endpoint login (Menghasilkan token)
@app.post("/login")
def login(login_data: LoginRequest):
    verify_admin(login_data.username, login_data.password)
    token = create_token(login_data.username)
    return {"access_token": token}

# Endpoint mendapatkan artikel yang dipublish (tanpa autentikasi)
@app.get("/articles")
def get_articles():
    articles = load_articles()
    published_articles = [a for a in articles if a["status"] == "published"]
    return published_articles

# Endpoint menambahkan artikel (Perlu autentikasi)
@app.post("/articles")
def add_article(article: CreateArticleRequest, username: str = Depends(get_current_admin)):
    articles = load_articles()
    article_id = str(len(articles) + 1)

    if article.status == "published":
        publish_at = article.publish_at or datetime.utcnow()
        unpublish_at = publish_at + timedelta(days=36500)  # 100 tahun
    else:
        publish_at = datetime.utcnow()
        unpublish_at = datetime.utcnow()

    new_article = {
        "id": article_id,
        "title": article.title,
        "url": article.url,
        "status": article.status,
        "publish_at": publish_at.isoformat(),
        "unpublish_at": unpublish_at.isoformat()
    }

    articles.append(new_article)
    save_articles(articles)
    return new_article

# Endpoint update artikel (Perlu autentikasi)
@app.put("/articles/{article_id}")
def update_article(article_id: str, update_data: UpdateArticleRequest, username: str = Depends(get_current_admin)):
    articles = load_articles()
    for article in articles:
        if article["id"] == article_id:
            if update_data.title:
                article["title"] = update_data.title
            if update_data.url:
                article["url"] = update_data.url
            if update_data.status:
                article["status"] = update_data.status
                if update_data.status == "published":
                    article["publish_at"] = (update_data.publish_at or datetime.utcnow()).isoformat()
                    article["unpublish_at"] = (datetime.utcnow() + timedelta(days=36500)).isoformat()
                else:
                    article["unpublish_at"] = datetime.utcnow().isoformat()
            save_articles(articles)
            return article

    raise HTTPException(status_code=404, detail="Article not found")
