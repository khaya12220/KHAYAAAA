from datetime import datetime, timezone
from typing import Any
from fastapi import FastAPI
from pydantic import BaseModel, Field

app = FastAPI(title='KHAYA API', version='1.0.0')
latest: dict[str, Any] | None = None
last_update: datetime | None = None

class EAStatus(BaseModel):
    ea_running: bool
    auto_trading: bool
    session_open: bool
    market_connected: bool
    symbols_monitored: int
    symbols_ready: int
    bullish_symbols: int
    bearish_symbols: int
    trading_allowed: bool
    weekend_closed: bool = False
    account_balance: float | None = None
    account_equity: float | None = None
    account_currency: str | None = None
    open_positions: int | None = None
    terminal_name: str | None = None
    broker_server: str | None = None
    terminal_vps: bool | None = None
    terminal_build: int | None = None
    positions: list[dict[str, Any]] = Field(default_factory=list)

@app.get('/')
def root(): return {'service':'KHAYA API','status':'online'}

@app.get('/health')
def health(): return {'status':'healthy'}

@app.post('/api/ea/status')
def receive_status(status: EAStatus):
    global latest, last_update
    latest = status.model_dump()
    last_update = datetime.now(timezone.utc)
    return {'accepted': True, 'received_at': last_update.isoformat()}

@app.get('/api/ea/status')
def status():
    return {'status': 'connected' if latest else 'waiting', 'last_update': last_update.isoformat() if last_update else None, 'ea': latest}
