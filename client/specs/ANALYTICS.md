# Ralph Loop Analytics Infrastructure Specification

## Purpose

Provide empirical measurement tools to validate performance assumptions about Ralph loop workflows in both **plan mode (Opus)** and **build mode (Sonnet)**. Enable informed decisions about Ollama backend feasibility based on actual data, not prompt rhetoric or theoretical limits.

## Problem Statement

### The Assumption Problem

Ralph loop prompts contain phrases like:
- "up to 250 parallel Sonnet subagents"
- "use up to 500 Sonnet subagents"

These are **capability envelopes**, not execution guarantees. Without measurement:
- Cannot predict Ollama backend performance
- Cannot validate hardware sufficiency
- Cannot identify bottlenecks
- Risk over-engineering (e.g., building multi-server infrastructure for workload that needs <20 concurrent)

### The Solution

**Empirical measurement** of actual Ralph loop behavior in both plan mode (Opus) and build mode (Sonnet):
- How many subagents actually spawn?
- What work do they do (shallow reads vs deep edits)?
- How much prompt caching matters?
- What are realistic hardware requirements?
- How do Opus (planning) and Sonnet (execution) differ in resource usage?

## Architecture

### Components

1. **`loop-with-analytics.sh`** - Enhanced loop runner with integrated measurement
2. **`compare-analytics.sh`** - Comparison tool for multiple runs
3. **`ANALYTICS_README.md`** - User guide and interpretation framework
4. **`analytics/run-TIMESTAMP/`** - Structured output directory per run

### Data Flow

```
┌─────────────────────────────────────┐
│ loop-with-analytics.sh              │
│  (wraps loop.sh functionality)      │
└───────────────┬─────────────────────┘
                │
                ├─ Execute: claude -p --output-format=stream-json
                │
                ├─ Capture: tee to iteration-N.json
                │
                ├─ Parse: grep/awk for metrics
                │
                ├─ Display: real-time per-iteration summary
                │
                └─ Aggregate: final run summary

                ↓

┌─────────────────────────────────────┐
│ analytics/run-TIMESTAMP/            │
│  ├── iteration-1.json               │
│  ├── iteration-1-analysis.txt       │
│  ├── iteration-2.json               │
│  ├── iteration-2-analysis.txt       │
│  └── summary.md                     │
└─────────────────────────────────────┘

                ↓

┌─────────────────────────────────────┐
│ compare-analytics.sh                │
│  (compare two runs side-by-side)    │
└─────────────────────────────────────┘
```

## Captured Metrics

### Per Iteration

#### Tool Usage Counts

- `Read` - File reads
- `Bash` - Shell command executions
- `Edit` - File edits (string replacement)
- `Write` - File creations/overwrites
- `Grep` - Content searches
- `Glob` - File pattern matching
- `Task` - **Subagent spawns** (critical metric)
- `TodoWrite` - Task list updates

**Total tools**: Sum of all tool calls

#### Token Usage

- `input_tokens` - Tokens processed from input
- `cache_creation_input_tokens` - Tokens written to cache
- `cache_read_input_tokens` - Tokens read from cache
- `output_tokens` - Tokens generated in response

**Derived metrics:**
- Total input: `input_tokens + cache_creation + cache_read`
- Cache hit rate: `cache_read / (cache_creation + cache_read) * 100%`

#### Workload Classification

**Shallow operations**: Read + Grep + Glob
- Characteristics: Fast, stateless, suitable for smaller models
- Example: "Find all TODO comments in src/"

**Deep operations**: Edit + Write
- Characteristics: Slower, stateful, require reasoning
- Example: "Refactor this class to use dependency injection"

**Ratio**: Shallow:Deep
- High ratio (>5:1): Read-heavy workload, Ollama suitable
- Low ratio (<2:1): Edit-heavy workload, quality critical

### Aggregate (Across All Iterations)

- Total subagents spawned
- Average subagents per iteration
- Total file reads / edits
- Total cache creation / reads
- Overall cache hit rate
- Shallow:deep ratio across run

### Real-Time Display

After each iteration:
```
═══════════════════════════════════════════════════════
   Iteration 2 Analytics
═══════════════════════════════════════════════════════
Tool Usage:
  Read: 18 | Bash: 5 | Edit: 3 | Write: 1
  Grep: 7 | Glob: 12 | Subagents: 8 | Todo: 1
  Total tools: 55

Token Usage:
  Input: 12,456 | Cache creation: 0 | Cache read: 34,428
  Output: 2,134 | Cache hit rate: 100%

Workload:
  Shallow ops (reads/greps/globs): 37
  Deep ops (edits/writes): 4
  Shallow:Deep ratio = 37:4
═══════════════════════════════════════════════════════
```

## Stored Artifacts

### Directory Structure

```
analytics/
└── run-20260210-143022/          # Timestamp-based run ID
    ├── iteration-1.json          # Raw Claude Code stream-json output
    ├── iteration-1-analysis.txt  # Parsed metrics for iteration 1
    ├── iteration-2.json
    ├── iteration-2-analysis.txt
    ├── iteration-3.json
    ├── iteration-3-analysis.txt
    └── summary.md                # Aggregate report with insights
```

### summary.md Format

```markdown
# Ralph Loop Analytics - Run 20260210-143022

**Mode**: plan
**Model**: opus
**Prompt**: PROMPT_plan.md
**Goal**: client & server full spec implementation
**Started**: 2026-02-10 14:30:22

---

## Iteration 1

| Metric | Value |
|--------|-------|
| **Tool calls** | 42 |
| Read | 15 |
| ... | ... |
| **Subagents (Task)** | **6** |
| **Cache hit rate** | **0%** |
| Shallow:Deep | 28:3 |

---

## Iteration 2

...

---

**Completed**: 2026-02-10 14:45:18
**Total iterations**: 3

## Key Findings

### Aggregate Statistics

- **Total subagents spawned**: 18
- **Average subagents per iteration**: 6
- **Total file reads**: 48
- **Cache hit rate**: 72%

### Analysis

The actual subagent spawn count was **6 per iteration** (average),
significantly different from the theoretical maximum of 250-500
mentioned in prompts. This confirms:

1. **Parallelism is sparse**: Most work done with reads, not hundreds of agents
2. **Cache efficiency**: 72% hit rate = prompt caching critical for performance
3. **Workload is read-heavy**: 48:9 read:edit ratio

### Implications for Ollama Migration

Based on empirical data:
- Single Ollama server can handle 6 concurrent subagents
- Lack of prompt caching will add ~2-3x latency (72% → 0% hit rate)
- Shallow operations (reads) dominate = suitable for local models
- **Recommendation**: Test with Ollama for build phase; keep Anthropic for plan phase
```

## Comparison Tool

### Usage

```bash
./compare-analytics.sh analytics/run-20260210-143022 analytics/run-20260210-150015
```

### Output

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
   Analytics Comparison
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Run 1: 20260210-143022 (Anthropic API)
Run 2: 20260210-150015 (Ollama)

Metric                         Run 1           Run 2       Diff
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Iterations                          3               3          0
Total subagents                    18              16         -2
Avg subagents/iter                  6               5         -1
Cache hit rate (%)                 72               0        -72
Output tokens                   6,234           7,891      1,657

Key Insights:
  ✓ Both runs used modest parallelism (<50 subagents/iter)
    → Single Ollama server likely sufficient
  ⚠ Run 1 benefited significantly from caching (72%)
    → Ollama (no caching) would be slower
  ✓ Workload is read-heavy (12:3 read:edit ratio)
    → Local models suitable for majority of operations
```

## Use Cases

### 0. Test Plan Mode with Opus (Phase 1: Planning Baseline)

**Question**: How does Opus perform in plan mode? What are the actual resource requirements and performance characteristics?

**Method**:
```bash
./loop-with-analytics.sh plan 1 -g "client & server full spec implementation"
```

**Look for**:
- Subagent spawns during planning phase (reconnaissance and deep analysis)
- Cache hit rate across multiple planning iterations
- Tool usage patterns (Read-heavy vs Edit-heavy during planning)
- Token consumption (Opus uses more tokens per response than Sonnet)
- Planning quality (iterations required to complete task)

**Expected result**:
- Fewer iterations than build mode (Opus converges faster)
- More complex tool orchestration
- Higher token usage per iteration
- Strong cache utilization after first iteration

**Analysis required after run**:
1. Review `analytics/run-TIMESTAMP/summary.md`
2. Check total subagent spawns (expect 5-15 per iteration)
3. Analyze cache hit rate progression (0% → 70-85%)
4. Examine tool usage distribution (Read/Grep/Glob vs Edit/Write)
5. Assess token consumption patterns (high input tokens for Opus)
6. Document findings for comparison with build mode

**Implication**:
- Opus planning phase is cache-dependent → remote Ollama not recommended for planning
- Plan quality critical → stick with Anthropic cloud for plan mode
- Build mode (Sonnet) may be viable for Ollama after planning complete

**Next step**: After analyzing plan mode results, proceed to test build mode (see Use Case #0b).

### 0b. Test Build Mode with Sonnet (Phase 2: Execution Baseline)

**Question**: How does Sonnet perform in build mode? What are the resource requirements compared to plan mode?

**Prerequisites**: Complete plan mode test (Use Case #0) and analyze results first

**Method**:
```bash
./loop-with-analytics.sh
```
(Defaults to build mode with Sonnet, continues from where plan mode left off)

**Look for**:
- Subagent spawns during execution phase (parallel implementation)
- Cache hit rate patterns (should be similar to plan mode after first iteration)
- Tool usage patterns (more Edit/Write than plan mode)
- Token consumption (Sonnet uses fewer tokens than Opus)
- Iteration count to completion (quality proxy)

**Expected result**:
- More iterations than plan mode (Sonnet executes incrementally)
- More Edit/Write operations (implementation-focused)
- Lower token usage per iteration
- Strong cache utilization after first iteration (60-75%)

**Analysis required after run**:
1. Review `analytics/run-TIMESTAMP/summary.md`
2. Check total subagent spawns (expect 8-20 per iteration)
3. Analyze cache hit rate (should be 60-75% after first iteration)
4. Compare tool usage distribution vs plan mode (more edits)
5. Assess token consumption vs Opus (should be lower)
6. Document quality metrics (test pass rate, iteration count)

**Comparison with plan mode**:
- Use `./compare-analytics.sh analytics/run-PLAN analytics/run-BUILD`
- Look for differences in:
  - Subagent counts (build typically spawns more)
  - Cache dependency (both should be cache-heavy)
  - Tool patterns (plan = reads, build = edits)
  - Token usage (Opus > Sonnet per iteration)

**Implication**:
- If build mode shows <20 subagents and >60% cache hit → remote Ollama might work for simple builds
- If build mode shows high Edit/Write ratio → quality matters, stick with Anthropic
- Cache dependency in both modes → remote Ollama not recommended for either without caching

**Why this matters**:
Testing build mode establishes the complete baseline for Ralph loop workflows. Only after understanding both phases empirically can informed decisions be made about remote Ollama viability.

### 1. Validate Parallelism Assumptions

**Question**: Do Ralph loops really need 250+ concurrent subagents?

**Method**:
```bash
./loop-with-analytics.sh plan 1 -g "full spec audit"
```

**Look for**: "Total subagents spawned" and "Average per iteration"

**Expected result**: 5-30 (not 250+)

**Implication**: Single server sufficient; no need for multi-server infrastructure

### 2. Measure Cache Dependency (Both Plan and Build Modes)

**Question**: How much does prompt caching help in planning vs execution?

**Method**:
```bash
# Test plan mode (Opus)
./loop-with-analytics.sh plan 3 -g "typical planning task"

# Test build mode (Sonnet)
./loop-with-analytics.sh 3 -g "typical build task"
```

**Look for**: "Cache hit rate" per iteration (should increase after first)

**Expected result**:
- Plan mode: 60-80% cache hit on iterations 2-3 (Opus benefits heavily from caching)
- Build mode: 50-70% cache hit on iterations 2-3 (Sonnet also cache-dependent)

**Implication**: Ollama (no caching) will be 2-3x slower for both modes if workload cache-heavy. This is why remote Ollama is **not recommended** for multi-iteration Ralph loops.

### 3. Classify Workload

**Question**: Is workload suitable for local models?

**Method**:
```bash
./loop-with-analytics.sh
```

**Look for**: "Shallow:Deep ratio"

**Expected result**: 3:1 to 10:1 (read-heavy)

**Implication**: High ratio = most work can use local models (reads don't need Opus)

### 4. Benchmark Ollama Performance (After Baseline Established)

**Prerequisites**: Complete baseline measurement with Anthropic cloud API first (use cases #0, #2)

**Method**:
1. Baseline (already done): Anthropic cloud with plan or build mode
2. Modify script to use `claude-ollama` alias
3. Ollama test: `./loop-with-analytics.sh plan 1 -g "same task"` (or build mode)
4. Compare: `./compare-analytics.sh analytics/run-BASELINE analytics/run-OLLAMA`

**Look for**:
- Iteration count difference (quality proxy - more iterations = lower quality)
- Wall time difference (performance - expect 2-3x slower without caching)
- Tool usage patterns (behavior changes indicate reasoning differences)
- Cache hit rate: 0% for Ollama vs 60-80% for Anthropic

**Implication**: Make data-driven decision about Ollama viability for specific workflow

**Important**: Always test plan mode (Opus) with Anthropic cloud first to establish baseline. Then test build mode (Sonnet) with Ollama if considering migration for execution phase only.

## Implementation Requirements

### loop-with-analytics.sh

**Must maintain 100% functional parity with loop.sh**:
- Same argument parsing (plan/build mode, max iterations, goal text)
- Same interactive goal editor
- Same sandbox/non-sandbox modes
- Same git integration (push after each iteration)
- Same completion detection (`.agent_complete` file)

**Additional behavior**:
- Capture all output via `tee` to `analytics/run-TIMESTAMP/iteration-N.json`
- Parse JSON after each iteration
- Display real-time metrics summary
- Save per-iteration analysis to `.txt` files
- Generate aggregate `summary.md` at end

**Performance impact**:
- Overhead: ~1-2 seconds per iteration (JSON parsing, grep/awk)
- Negligible compared to iteration time (typically 2-10 minutes)

### compare-analytics.sh

**Input**: Two analytics run directories
**Output**: Side-by-side comparison table + insights
**Format**: Human-readable terminal output

**Insights generation**:
- Detect modest parallelism (<50 subagents) → "single server sufficient"
- Detect high cache rate (>50%) → "Ollama slower without caching"
- Detect read-heavy workload (>5:1) → "suitable for local models"

### Parsing Logic

**Tool counting**:
```bash
grep -c '"name":"Read"' iteration-N.json
```

**Token extraction**:
```bash
grep -o '"cache_read_input_tokens":[0-9]*' iteration-N.json | \
  awk -F: '{sum+=$2} END {print sum+0}'
```

**Cache hit rate calculation**:
```bash
cache_hit_rate=$((cache_read * 100 / (cache_creation + cache_read)))
```

## Interpretation Framework

### Decision Matrix

| Mode | Subagents/iter | Cache hit | Shallow:Deep | Recommendation |
|------|----------------|-----------|--------------|----------------|
| **Plan (Opus)** | Any | >50% | Any | ❌ Keep Anthropic cloud (quality critical) |
| **Build (Sonnet)** | <10 | <30% | >5:1 | ✅ Consider Ollama for simple builds |
| **Build (Sonnet)** | <20 | 30-60% | 3:1-5:1 | ⚠️ Test Ollama carefully |
| **Build (Sonnet)** | <20 | >60% | <3:1 | ❌ Keep Anthropic (cache-dependent) |
| **Build (Sonnet)** | >50 | Any | Any | ❌ Keep Anthropic (parallelism) |

**Key insight**: Plan mode (Opus) should always use Anthropic cloud for quality. Only consider remote Ollama for build mode (Sonnet) after establishing baseline.

### Quality Assessment

Metrics cannot measure:
- Plan coherence
- Code correctness
- Architectural soundness
- Iteration efficiency (did it converge faster?)

**Manual review required** for quality comparison between Anthropic and Ollama runs.

## Testing Requirements

### Validation

Before production use:
1. Run `loop-with-analytics.sh` with known-good task
2. Verify metrics match expected patterns
3. Compare with non-analytics `loop.sh` output (should be identical except for analytics display)
4. Test comparison tool with two different runs
5. Verify `summary.md` formatting

### Edge Cases

- **Zero iterations**: Script should handle gracefully (no analytics)
- **Single iteration**: Should still produce summary
- **Max iterations reached**: Should still complete analytics
- **Agent completion early**: Should still finalize summary

## Future Enhancements

### Potential Additions

1. **Time tracking**: Measure wall time per tool call
2. **Failure analysis**: Track which tests/commands fail
3. **Model switching**: Track when/why subagents switch models
4. **Git metrics**: Lines changed, files touched, commits created
5. **Cost estimation**: Token costs for Anthropic API vs hardware for Ollama
6. **Quality scoring**: Automated heuristics (test pass rate, code complexity)

### Out of Scope

- Real-time streaming display (current: after-iteration summaries)
- Interactive filtering (e.g., "show only Edit tools")
- Web dashboard UI
- Database storage (current: flat files)
- Multi-run aggregation (beyond pairwise comparison)

## Summary

Analytics infrastructure provides:
- **Visibility**: Actual Ralph loop behavior vs prompt assumptions (both plan and build modes)
- **Validation**: Empirical data for Ollama feasibility decisions (mode-specific)
- **Optimization**: Identify bottlenecks (cache dependency, parallelism, etc.)
- **Accountability**: Reproducible measurements for architecture choices
- **Baseline establishment**: Two-phase testing (plan then build) to understand complete workflow

**Critical for informed decision-making** about remote Ollama backend adoption.

**Recommended testing workflow**:

**Phase 1: Plan Mode (Opus)**
```bash
./loop-with-analytics.sh plan 1 -g "client & server full spec implementation"
```
- Establishes planning baseline
- Validates analytics infrastructure
- Measures Opus resource usage and cache dependency

**After Phase 1: Analyze Results**
- Review `analytics/run-TIMESTAMP/summary.md`
- Document subagent counts, cache hit rates, tool patterns
- Understand planning phase characteristics

**Phase 2: Build Mode (Sonnet)**
```bash
./loop-with-analytics.sh
```
- Establishes execution baseline
- Measures Sonnet resource usage
- Compares with plan mode patterns

**After Phase 2: Analyze and Compare**
- Review build mode `summary.md`
- Use `./compare-analytics.sh` to compare plan vs build
- Make data-driven decisions about remote Ollama viability

**Both phases required** for complete empirical understanding of Ralph loop workflows.
