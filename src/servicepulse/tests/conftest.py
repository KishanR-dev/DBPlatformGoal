"""Test configuration and shared fixtures."""

import pytest
from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from sqlalchemy.pool import StaticPool

from app.core.config import Settings
from app.core.metrics import metrics
from app.db.database import Base, get_db
from app.main import app


# Override settings for testing
class TestSettings(Settings):
    app_env: str = "test"
    database_url: str = "sqlite:///:memory:"


# In-memory test database setup with StaticPool for total isolation and ultra-fast speed
SQLALCHEMY_DATABASE_URL = "sqlite:///:memory:"
engine = create_engine(
    SQLALCHEMY_DATABASE_URL,
    connect_args={"check_same_thread": False},
    poolclass=StaticPool,
)
TestingSessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)


@pytest.fixture(autouse=True)
def reset_metrics():
    """Reset the metrics collector before each test to guarantee complete isolation."""
    metrics.reset()
    yield
    metrics.reset()


@pytest.fixture(scope="function")
def db_session():
    """Create a fresh database for each test with isolated tables."""
    Base.metadata.create_all(bind=engine)
    db = TestingSessionLocal()
    try:
        yield db
    finally:
        db.close()
        Base.metadata.drop_all(bind=engine)


@pytest.fixture(scope="function")
def client(db_session):
    """Create a test client with database override."""

    def override_get_db():
        try:
            yield db_session
        finally:
            pass

    app.dependency_overrides[get_db] = override_get_db
    with TestClient(app) as c:
        yield c
    app.dependency_overrides.clear()


@pytest.fixture
def sample_request_data():
    return {
        "customer_id": "CUST-001",
        "request_type": "SERVICE",
        "description": "Unable to access account",
    }


@pytest.fixture
def sample_incident_data():
    return {
        "title": "Elevated processing failures",
        "description": "Processing failure rate exceeded threshold",
        "severity": "HIGH",
        "affected_service": "request_processing",
    }
