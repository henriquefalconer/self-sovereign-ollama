<!--
 Copyright (c) 2026 Henrique Falconer. All rights reserved.
 SPDX-License-Identifier: Proprietary
-->

# Implementation Plan

**Last Updated**: 2026-02-11
**Current Version**: v0.0.18

---

## Current Status

### Client Implementation - COMPLETE

All 9 client specs fully implemented: 6 scripts + env.template + documentation. 40 tests in client test suite. v1 (Aider/OpenAI) and v2+ (Claude Code/Anthropic, version management, analytics) all operational. Bug fixes from hardware testing applied (timing, JSON parsing, macOS timeout, install.sh undefined function).

### Server Implementation - PARTIAL (HAProxy proxy layer missing)

v1 API surface works (Ollama serves OpenAI + Anthropic endpoints). 26 tests in server test suite. **Critical gap**: The three-layer architecture specified across 6+ specs (ARCHITECTURE, SECURITY, INTERFACES, FILES, FUNCTIONALITIES, SCRIPTS) is not implemented. HAProxy is completely absent from all server scripts. Ollama binds to `0.0.0.0` instead of `127.0.0.1`.

---

## Remaining Tasks (Priority Order)

### Phase 5: Server HAProxy Proxy Layer

The server specs define a three-layer security architecture:
```
Client → Tailscale → HAProxy (100.x.x.x:11434) → Ollama (127.0.0.1:11434)
```

Current implementation bypasses HAProxy entirely:
```
Client → Tailscale → Ollama (0.0.0.0:11434)
```

This is documented in ARCHITECTURE.md, SECURITY.md, INTERFACES.md, FILES.md, FUNCTIONALITIES.md, and partially in SCRIPTS.md. The specs are clear and consistent (except SCRIPTS.md line 34 which matches the current implementation rather than the architectural spec).

| # | Task | Priority | Effort | Target Files | Details |
|---|------|----------|--------|--------------|---------|
| 1 | **Resolve SCRIPTS.md spec inconsistency** | H1 | Small | `server/specs/SCRIPTS.md` | Line 34 says `OLLAMA_HOST=0.0.0.0`; all other specs say `127.0.0.1`. Align SCRIPTS.md with ARCHITECTURE.md (update to `127.0.0.1` + add HAProxy install section) or align all other specs with current implementation. This decision gates all subsequent work. |
| 2 | **Add HAProxy installation to install.sh** | H1 | Large | `server/scripts/install.sh` | Per FUNCTIONALITIES.md lines 147-159: Install HAProxy via Homebrew (with user consent prompt per lines 160-184), create `~/.haproxy/haproxy.cfg` with endpoint allowlist (per FILES.md lines 48-83), create `com.haproxy.plist` LaunchAgent (per FILES.md lines 39-46), change `OLLAMA_HOST` from `0.0.0.0` to `127.0.0.1`, load both services, verify proxy forwarding. |
| 3 | **Add HAProxy cleanup to uninstall.sh** | H1 | Small | `server/scripts/uninstall.sh` | Per FILES.md lines 185-195: Stop and remove `com.haproxy.plist`, delete `~/.haproxy/` directory, clean up `/tmp/haproxy.log`. |
| 4 | **Update test.sh for proxy architecture** | H2 | Medium | `server/scripts/test.sh` | Per FUNCTIONALITIES.md lines 213-224: Change Test 17 to verify `OLLAMA_HOST=127.0.0.1` (not `0.0.0.0`). Change Test 18 to verify loopback-only binding. Add HAProxy-specific tests: HAProxy service loaded, HAProxy listening on Tailscale interface, endpoint allowlist enforcement (blocked paths return 403/404), Ollama unreachable directly from Tailscale IP. |
| 5 | **Update server README.md and SETUP.md** | H3 | Small | `server/README.md`, `server/SETUP.md` | Ensure documentation matches actual implementation after HAProxy is added. README.md already references HAProxy (written for the spec), so minimal changes expected. |

### Phase 6: Documentation Gaps

| # | Task | Priority | Effort | Target Files | Details |
|---|------|----------|--------|--------------|---------|
| 6 | **Update client/README.md** | H3 | Small | `client/README.md` | Lines 3, 8, 10, 21-24 say v2+ is "planned" / "not yet implemented" but it IS implemented. Update to reflect current reality. |
| 7 | **Add root-level scripts to client/specs/SCRIPTS.md** | H4 | Small | `client/specs/SCRIPTS.md` | Formally specify `loop.sh`, `loop-with-analytics.sh`, and `compare-analytics.sh` (documented elsewhere but missing from SCRIPTS.md spec). |

### Phase 7: Hardware Validation

| # | Task | Priority | Effort | Target Files | Details |
|---|------|----------|--------|--------------|---------|
| 8 | **Hardware testing re-run** | H3 | Medium | Manual | Run server tests with `--verbose` on Apple Silicon, manual Claude Code + Ollama validation, test version management scripts, run client tests. All script bugs have been fixed. Expected: 25/26 server, 31+/40 client tests pass. |

---

## Dependency Graph

```
Phase 5 (HAProxy proxy layer):
  #1 (spec resolution) ─── gates all below
    ├── #2 (install.sh HAProxy) ─── requires #1
    ├── #3 (uninstall.sh cleanup) ─── requires #1
    └── #4 (test.sh updates) ─── requires #2
  #5 (docs update) ─── requires #2

Phase 6 (documentation, independent):
  #6 (client README) ─── no dependencies
  #7 (SCRIPTS.md spec) ─── no dependencies

Phase 7 (validation):
  #8 (hardware testing) ─── requires #2, #4
```

---

## Effort Summary

| Category | Items | Effort |
|----------|-------|--------|
| Spec resolution (SCRIPTS.md inconsistency) | #1 | Small |
| Server install.sh (HAProxy + loopback) | #2 | Large |
| Server uninstall.sh (HAProxy cleanup) | #3 | Small |
| Server test.sh (proxy architecture tests) | #4 | Medium |
| Server documentation updates | #5 | Small |
| Client README.md (outdated v2+ status) | #6 | Small |
| Client SCRIPTS.md (root-level scripts spec) | #7 | Small |
| Hardware testing re-run | #8 | Medium (requires physical access) |

---

## Implementation Constraints

1. **Security**: Tailscale-only network. No public exposure. No built-in auth.
2. **API contract**: `client/specs/API_CONTRACT.md` is the single source of truth for server-client interface.
3. **Idempotency**: All scripts must be safe to re-run without side effects.
4. **No stubs**: Implement completely or not at all. No TODO/FIXME/HACK in production code.
5. **Claude Code integration is optional**: Always prompt for user consent. Anthropic cloud is default; Ollama is an alternative.
6. **curl-pipe install**: Client `install.sh` must work when executed via `curl | bash`.
7. **HAProxy is optional but recommended**: User consent prompt required per FUNCTIONALITIES.md. Default: Yes. Without it, Ollama falls back to `0.0.0.0` binding (less secure but functional).

---

## Completed Work Summary

### v1 (Aider/OpenAI API) - COMPLETE
- Server: install.sh, uninstall.sh, warm-models.sh, test.sh (26 tests)
- Client: install.sh, uninstall.sh, test.sh (40 tests), env.template

### v2+ (Claude Code/Anthropic API) - COMPLETE
- Server: Anthropic API tests added to test.sh (tests 21-26), `--skip-anthropic-tests` flag
- Client: Claude Code install step, `claude-ollama` alias, uninstall v2+ cleanup
- Version management: check-compatibility.sh, pin-versions.sh, downgrade-claude.sh
- Analytics: loop-with-analytics.sh, compare-analytics.sh, ANALYTICS_README.md, decision matrix
- Documentation: client/SETUP.md (v2+ sections), server/README.md (Anthropic test docs)
- Testing: 12 client v2+ tests (29-40), `--skip-claude`/`--v1-only`/`--v2-only` flags

### Bug Fixes Applied (v0.0.17-v0.0.18)
- `grep -c` exit code handling in analytics scripts
- Server test.sh: timing calculation (nanosecond detection), Anthropic endpoint detection (verbose mode JSON parsing)
- Client test.sh: same timing + JSON parsing bugs, macOS timeout compatibility
- Client install.sh: undefined `success()` function call

---

## Lessons Learned

### v0.0.4: OLLAMA_API_BASE Bug
All automated tests passed, but real Aider usage failed. Root cause: `OLLAMA_API_BASE` included `/v1` suffix. Fix: separate `OLLAMA_API_BASE` (no suffix) from `OPENAI_API_BASE` (with `/v1`). **Lesson**: End-to-end integration tests with actual tools are mandatory.

### v0.0.18: Test Harness Bugs
Hardware tests showed false failures/skips due to test script bugs, not API failures. **Lesson**: When tests fail unexpectedly, examine raw API responses first — the problem may be in the measurement, not the code being measured.

---

## Spec Baseline

All work must comply with:
- `server/specs/*.md` (9 files including ANTHROPIC_COMPATIBILITY, HARDENING_OPTIONS)
- `client/specs/*.md` (9 files including ANALYTICS, CLAUDE_CODE, VERSION_MANAGEMENT)

Specs are authoritative. Implementation deviations must be corrected unless there is a compelling reason to update the spec.
