from datetime import datetime

from pydantic import BaseModel, ConfigDict, Field, field_validator

from task import to_utc_datetime


class User(BaseModel):
    model_config = ConfigDict(arbitrary_types_allowed=True)

    uid: str | None = None
    github_access_token: str | None = None
    github_username: str | None = None
    gemini_api_key: str | None = None
    last_assigned_sync: datetime | None = None
    last_mentioned_sync: datetime | None = None
    last_created_sync: datetime | None = None
    monitored_repos: dict[str, datetime | None] = Field(default_factory=dict)

    @field_validator(
        "last_assigned_sync",
        "last_mentioned_sync",
        "last_created_sync",
        mode="after",
    )
    @classmethod
    def _ensure_utc(cls, v: datetime | None) -> datetime | None:
        return to_utc_datetime(v)

    @field_validator("monitored_repos", mode="after")
    @classmethod
    def _ensure_monitored_repos_utc(
        cls, v: dict[str, datetime | None]
    ) -> dict[str, datetime | None]:
        return {repo: to_utc_datetime(dt) for repo, dt in v.items()}
