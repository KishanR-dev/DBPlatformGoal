"""Application configuration loaded from environment variables."""

from pydantic_settings import BaseSettings


class Settings(BaseSettings):
    """Centralized application settings.

    All values are configurable via environment variables or a .env file.
    """

    # Application
    app_env: str = "development"
    app_name: str = "ServicePulse"
    app_version: str = "1.4.0"
    app_host: str = "0.0.0.0"  # nosec B104
    app_port: int = 8000
    log_level: str = "INFO"

    # Database
    database_url: str = "sqlite:///./servicepulse.db"

    # Failure simulation — only active when BOTH conditions are true:
    # app_env == "development" AND failure_simulation_enabled == True
    failure_simulation_enabled: bool = False

    @property
    def is_failure_simulation_active(self) -> bool:
        """Failure simulation requires development environment AND explicit opt-in."""
        return self.app_env == "development" and self.failure_simulation_enabled

    model_config = {"env_file": ".env", "env_file_encoding": "utf-8"}


def get_settings() -> Settings:
    """Create a Settings instance. Not cached — tests can override env vars freely."""
    return Settings()
