# remote-ollama ai-server Functionalities (v1)

## Core Functionality

- One-time installer that configures Ollama as a LaunchAgent service
- Uninstaller that removes only server-side LaunchAgent configuration
- Ollama serves OpenAI-compatible HTTP endpoint at `/v1`
- Optional model pre-warming script for boot-time loading
- Comprehensive test script for automated validation of all server functionality
- Service management via standard launchctl commands (start/stop/restart/status)

## Exposed APIs

### OpenAI-Compatible API (v1)

- HTTP endpoint at `/v1`
- Primary route: `/v1/chat/completions`
- Supports:
  - Streaming (stream: true)
  - Non-streaming responses
  - JSON structured output (format: "json")
  - Tool / function calling (when underlying model implements it)
  - System, user, assistant message roles
- Model selection via `model` parameter (any model available on the server)
- **Primary clients**: Aider, Continue, OpenAI SDKs with custom base_url

### Anthropic-Compatible API (v2+)

- HTTP endpoint at `/v1/messages`
- Anthropic Messages API compatibility layer
- Supports:
  - Messages with text and image content (base64)
  - Streaming via Server-Sent Events (SSE)
  - System prompts
  - Multi-turn conversations
  - Tool use (function calling)
  - Thinking blocks
- Limitations:
  - No `tool_choice` parameter
  - No prompt caching
  - No PDF/document support
  - Image URLs not supported (base64 only)
- Model selection via `model` parameter (same models as OpenAI API)
- **Primary clients**: Claude Code, Anthropic SDKs with custom base_url

## Server Behavior Requirements

- Automatic model loading on first request (or pre-warming via optional script)
- Graceful handling of concurrent requests (Ollama-level queuing / concurrency)
- Keep-alive of frequently used models in memory when possible
- Clean shutdown / restart without losing in-flight generations (best-effort)

## Intended Testing Scope (non-normative)

- Large instruction-tuned models (30B–70B+ class)
- Code-specialized models
- Quantized variants suitable for Apple Silicon unified memory

## Performance Expectations (non-normative guidance)

- Low added latency for worldwide clients (dependent on upload bandwidth)
- Reasonable throughput on large models when kept resident
