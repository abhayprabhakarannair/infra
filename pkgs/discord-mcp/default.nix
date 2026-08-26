{
  pkgs,
  lib,
  fetchFromGitHub,
  python312,
}:
python312.pkgs.buildPythonPackage rec {
  pname = "discord-mcp";
  version = "1.0.0";
  pyproject = true;

  src = fetchFromGitHub {
    owner = "ExilProductions";
    repo = "discord-mcp";
    rev = "337d5c8dbb3ff208fc613f5797ef7e9de427b763";
    hash = "sha256-kumlYMD9b7nT22rjFKDihQYv0jduoL99i4HaiB3Ui0U=";
  };

  build-system = [python312.pkgs.hatchling];

  dependencies = with python312.pkgs; [
    fastmcp
    discordpy
    uvicorn
    pydantic
    pydantic-settings
    python-dotenv
    structlog
    httpx
  ];

  pythonImportsCheck = ["discord_mcp"];

  meta = with lib; {
    description = "Production-grade MCP server for Discord (FastMCP + discord.py)";
    license = licenses.mit;
    maintainers = [];
  };
}
