from pydantic_settings import BaseSettings
from pathlib import Path


class Settings(BaseSettings):
    database_url: str = "postgresql+psycopg://veka:veka_secret@localhost:5432/veka"
    mediamtx_url: str = "http://localhost:9997"
    media_path: str = "/channels"
    overlay_path: str = "/overlays"
    hls_base_url: str = "http://localhost:8888"
    api_host: str = "0.0.0.0"
    api_port: int = 8000

    class Config:
        env_file = ".env"
        env_file_encoding = "utf-8"


settings = Settings()
