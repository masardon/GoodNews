from fastapi import FastAPI, HTTPException, Depends, BackgroundTasks
from pydantic import BaseModel, HttpUrl
from typing import List, Optional
from datetime import datetime
import os
from dotenv import load_dotenv
import bcrypt
from apscheduler.schedulers.background import BackgroundScheduler
import json

app = FastAPI()

# Load environment variables from .secrets.env
load_dotenv(dotenv_path="creds/.secrets.env")

# Data model for an article
class Article(BaseModel):
    title: str
    url: HttpUrl
    created_at: datetime = None
    updated_at: datetime = None
    status: str = "unpublished"  # Default status
    user_id: str = None  # User ID who created or updated the article (only for Admin)
    publish_at: Optional[datetime] = None  # Scheduled publish time
    unpublish_at: Optional[datetime] = None  # Scheduled unpublish time

# In-memory database (just for development)
articles_db: List[Article] = []

# Data model for a user
class User(BaseModel):
    user_id: str
    role: str

# Load admin user from environment variables
admin_user_id = os.getenv("ADMIN_USER_ID")
admin_password = os.getenv("ADMIN_PASSWORD")

# In-memory user database (just for development)
users_db = {
    admin_user_id: User(user_id=admin_user_id, role="Admin")
}

# Dependency to get the current user (for simplicity, we use a fixed user ID)
def get_current_user():
    return users_db[admin_user_id]  # Replace with actual user retrieval logic

# Dependency to check if the current user is an Admin
def get_current_admin_user(user: User = Depends(get_current_user)):
    if user.role != "Admin":
        raise HTTPException(status_code=403, detail="Operation not permitted")
    return user

# Scheduler for background tasks
scheduler = BackgroundScheduler()
scheduler.start()

def check_article_status():
    now = datetime.utcnow()
    for article in articles_db:
        if article.publish_at and article.publish_at <= now and article.status == "unpublished":
            article.status = "published"
            article.updated_at = now
        if article.unpublish_at and article.unpublish_at <= now and article.status == "published":
            article.status = "unpublished"
            article.updated_at = now

# Add job to scheduler to run every minute
scheduler.add_job(check_article_status, 'interval', minutes=1)

def save_articles_to_file():
    with open("data/articles_db.json", "w") as file:
        json.dump([article.dict() for article in articles_db], file, default=str)

def load_articles_from_file():
    global articles_db
    try:
        with open("data/articles_db.json", "r") as file:
            articles_data = json.load(file)
            articles_db = [Article(**article) for article in articles_data]
    except FileNotFoundError:
        articles_db = []

@app.on_event("startup")
def on_startup():
    load_articles_from_file()

@app.on_event("shutdown")
def on_shutdown():
    save_articles_to_file()

@app.get("/")
def read_root():
    return {"message": "Welcome to the Article API"}

@app.get("/articles", response_model=List[Article])
def get_articles():
    # Return only published articles
    return [article for article in articles_db if article.status == "published"]

@app.post("/articles", status_code=201)
def add_article(article: Article, user: User = Depends(get_current_admin_user)):
    # Check for duplicate URL
    for existing_article in articles_db:
        if existing_article.url == article.url:
            raise HTTPException(status_code=400, detail="Article with this URL already exists")
    article.created_at = datetime.utcnow()
    article.updated_at = datetime.utcnow()
    article.user_id = user.user_id
    articles_db.append(article)
    return {"message": "Article added successfully", "article": article}

@app.put("/articles/{article_url}", response_model=Article)
def update_article(article_url: HttpUrl, updated_article: Article, user: User = Depends(get_current_admin_user)):
    for article in articles_db:
        if article.url == article_url:
            article.title = updated_article.title
            article.updated_at = datetime.utcnow()
            article.status = updated_article.status
            article.user_id = user.user_id
            article.publish_at = updated_article.publish_at
            article.unpublish_at = updated_article.unpublish_at
            return article
    raise HTTPException(status_code=404, detail="Article not found")

@app.put("/articles/{article_url}/status", response_model=Article)
def update_article_status(article_url: HttpUrl, status: str, user: User = Depends(get_current_admin_user)):
    for article in articles_db:
        if article.url == article_url:
            article.status = status
            article.updated_at = datetime.utcnow()
            article.user_id = user.user_id
            return article
    raise HTTPException(status_code=404, detail="Article not found")
