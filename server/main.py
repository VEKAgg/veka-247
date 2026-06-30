import asyncio
from contextlib import asynccontextmanager
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from config import settings
from database import engine

from routers import channels, platforms, clips, alerts, irl, streams


@asynccontextmanager
async def lifespan(app: FastAPI):
    yield
    await engine.dispose()


app = FastAPI(
    title="veka-247 API",
    description="Multi-channel 24/7 streaming server backend",
    version="1.0.0",
    lifespan=lifespan,
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(channels.router, prefix="/api/channels", tags=["channels"])
app.include_router(platforms.router, prefix="/api/channels", tags=["platforms"])
app.include_router(clips.router, prefix="/api/channels", tags=["clips"])
app.include_router(alerts.router, prefix="/api/alerts", tags=["alerts"])
app.include_router(irl.router, prefix="/api/irl", tags=["irl"])
app.include_router(streams.router, prefix="/api/streams", tags=["streams"])


@app.get("/api/health")
async def health():
    return {"status": "ok", "service": "veka-247"}


if __name__ == "__main__":
    import uvicorn
    uvicorn.run(
        "main:app",
        host=settings.api_host,
        port=settings.api_port,
        reload=False,
    )
