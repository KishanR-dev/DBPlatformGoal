"""Common schema components shared across endpoints."""

from pydantic import BaseModel


class PaginatedResponse(BaseModel):
    """Wrapper for paginated list responses."""

    total: int
    skip: int
    limit: int
