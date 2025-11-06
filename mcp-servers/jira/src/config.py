"""Configuration management for MCP Jira Server."""

import os
from pathlib import Path
from typing import Dict, Optional

import yaml
from pydantic import Field, field_validator
from pydantic_settings import BaseSettings, SettingsConfigDict


class JiraConfig(BaseSettings):
    """Jira connection configuration."""

    model_config = SettingsConfigDict(
        env_prefix="JIRA_",
        env_file=".env",
        env_file_encoding="utf-8",
        extra="ignore",
    )

    # Connection settings
    url: str = Field(..., description="Jira instance URL")
    user_email: str = Field(..., description="Jira user email")
    api_token: str = Field(..., description="Jira API token")

    # OAuth settings (optional)
    oauth_client_id: Optional[str] = Field(None, description="OAuth client ID")
    oauth_client_secret: Optional[str] = Field(None, description="OAuth client secret")

    # API settings
    timeout: int = Field(30, description="API request timeout in seconds")
    max_retries: int = Field(3, description="Maximum number of retry attempts")
    rate_limit: int = Field(10, description="Requests per second limit")

    # Default values
    default_project: str = Field("HOMELAB", description="Default project key")
    default_issue_type: str = Field("Task", description="Default issue type")
    max_results: int = Field(100, description="Maximum search results")

    @field_validator("url")
    @classmethod
    def validate_url(cls, v: str) -> str:
        """Ensure URL doesn't end with a slash."""
        return v.rstrip("/")


class MCPServerConfig(BaseSettings):
    """MCP server configuration."""

    model_config = SettingsConfigDict(
        env_prefix="MCP_SERVER_",
        env_file=".env",
        env_file_encoding="utf-8",
        extra="ignore",
    )

    host: str = Field("0.0.0.0", description="Server host")
    port: int = Field(8001, description="Server port")
    log_level: str = Field("INFO", description="Logging level")


class CustomFieldsConfig(BaseSettings):
    """Custom field mappings."""

    story_points: str = "customfield_10016"
    epic_link: str = "customfield_10014"
    sprint: str = "customfield_10020"

    @classmethod
    def from_yaml(cls, config_file: Path) -> "CustomFieldsConfig":
        """Load custom fields from YAML config."""
        if not config_file.exists():
            return cls()

        with open(config_file) as f:
            data = yaml.safe_load(f)
            custom_fields = data.get("custom_fields", {})
            return cls(**custom_fields)


class IssueTypeMapping(BaseSettings):
    """Issue type ID mappings."""

    story: int = 10001
    task: int = 10002
    bug: int = 10003
    epic: int = 10000

    @classmethod
    def from_yaml(cls, config_file: Path) -> "IssueTypeMapping":
        """Load issue types from YAML config."""
        if not config_file.exists():
            return cls()

        with open(config_file) as f:
            data = yaml.safe_load(f)
            issue_types = data.get("issue_types", {})
            return cls(**issue_types)


class Config:
    """Main configuration container."""

    def __init__(self, config_file: Optional[Path] = None):
        """Initialize configuration."""
        self.jira = JiraConfig()
        self.mcp_server = MCPServerConfig()

        # Load YAML config if provided
        if config_file and config_file.exists():
            self.custom_fields = CustomFieldsConfig.from_yaml(config_file)
            self.issue_types = IssueTypeMapping.from_yaml(config_file)
        else:
            # Use defaults
            self.custom_fields = CustomFieldsConfig()
            self.issue_types = IssueTypeMapping()

    def to_dict(self) -> Dict:
        """Convert config to dictionary."""
        return {
            "jira": self.jira.model_dump(),
            "mcp_server": self.mcp_server.model_dump(),
            "custom_fields": self.custom_fields.model_dump(),
            "issue_types": self.issue_types.model_dump(),
        }


def load_config(config_file: Optional[str] = None) -> Config:
    """Load configuration from environment and optional YAML file."""
    config_path = Path(config_file) if config_file else None
    return Config(config_path)
