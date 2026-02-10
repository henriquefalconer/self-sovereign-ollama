# remote-ollama ai-server Repository Layout

```
server/
├── specs/                     # This folder — all markdown specifications
│   ├── ARCHITECTURE.md
│   ├── FUNCTIONALITIES.md
│   ├── SECURITY.md
│   ├── INTERFACES.md
│   ├── REQUIREMENTS.md
│   ├── SCRIPTS.md
│   ├── FILES.md
│   └── ANTHROPIC_COMPATIBILITY.md  # v2+ Anthropic API specification
├── scripts/
│   ├── install.sh             # One-time setup script for server machine
│   ├── uninstall.sh           # Remove server-side LaunchAgent and plist
│   ├── warm-models.sh         # Optional: pre-load models at boot / startup
│   └── test.sh                # Comprehensive server functionality tests
├── SETUP.md                   # Setup instructions
└── README.md                  # Overview and quick start
```

## Dual API Support (v2+)

The server exposes both OpenAI-compatible and Anthropic-compatible APIs:

**OpenAI API (v1)**:
- For Aider and OpenAI-compatible tools
- Endpoints at `/v1/chat/completions`, `/v1/models`, etc.

**Anthropic API (v2+)**:
- For Claude Code and Anthropic-compatible tools
- Endpoint at `/v1/messages`
- Requires Ollama 0.5.0+
- See `ANTHROPIC_COMPATIBILITY.md` for details

Both APIs served by the same Ollama process on port 11434.

No additional files or configuration required beyond standard Ollama installation.
