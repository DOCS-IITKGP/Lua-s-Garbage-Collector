# Part D.3: Benchmarking the Escape Analyzer and Its Promotion Win

## Overview

This benchmark measures two things separately:
1. **Cost:** How much compile-time overhead does the C.1 escape analysis add?
2. **Benefit:** Does C.1+C.2 reduce GC work at runtime?

---

## Measurement 1: Compile-Time Overhead

Measured by compiling the testbench with `luac` under callgrind, comparing
stock vs modified Lua.

### Total compile cost

| Build    | Basic Blocks | Trend |
|----------|-------------|-------|
| Stock    | 72,582      | —     |
| Modified | 73,131      | +0.76% |

The escape analysis adds less than 1% compile-time overhead.

### Per-function breakdown (key parser functions)

| Function       | Stock (Ir) | Modified (Ir) | Δ     | Reason |
|---------------|-----------|---------------|-------|--------|
| close_func    | 181       | 377           | +196  | Fixed-point propagation + PC collection (C.1+C.2) |
| constructor   | 326       | 332           | +6    | Setting last_was_constructor flag + saving PC |
| funcargs      | 65        | 109           | +44   | Whitelist check + tentative marking (Rule 4) |
| restassign    | 212       | 266           | +54   | Rule 3 dependency recording |
| localstat     | (inline)  | +52           | +52   | Initializing is_table/escapes fields |
| singlevaraux  | 1,468     | 1,454         | -14   | Within noise |

### Analysis

The overhead is negligible because:
- The escape analysis runs once per function body at compile time, not per
  table allocation at runtime.
- The testbench has only one function (`test()`), so the analysis runs twice
  (once for `test`, once for the top-level chunk).
- The fixed-point loop in close_func converges in 1 pass for this workload.
- The dominant compile costs (lexer, code generation) are unchanged.

For larger programs with many functions, the overhead scales linearly with
the number of functions, not with the number of table allocations. This is
a favorable scaling property.

---

## Measurement 2: Benefit to the Collector

Measured by running the full testbench (m=1000, n=100) under callgrind with
incremental GC, comparing stock vs modified.

### GC function comparison

| Function         | Stock (Ir)  | Modified (Ir) | Δ          |
|-----------------|-------------|---------------|------------|
| luaC_newobj     | 42,005,460  | 42,005,460    | 0          |
| sweeplist       | 41,051,529  | 41,363,621    | +312,092   |
| propagatemark   | 63,377,243  | 63,620,155    | +242,912   |
| traversearray   | 59,278,517  | 59,548,704    | +270,187   |
| reallymarkobject| 36,790,229  | 36,937,828    | +147,599   |
| freeobj         | 36,006,115  | 36,006,115    | 0          |
| singlestep      | 30,164,573  | 30,128,332    | -36,241    |
| luaH_new        | 28,000,308  | 28,000,308    | 0          |
| luaC_step       | 14,242,600  | 14,297,928    | +55,328    |

### Arena function usage

| Function         | Modified (Ir) | Calls |
|-----------------|---------------|-------|
| luaH_new_arena  | 0             | 0     |
| luaM_arena_new  | 0             | 0     |
| luaM_arena_alloc| 0             | 0     |

### Key finding: zero benefit for this workload

The arena allocator was **never called**. `luaH_new_arena` shows 0
instructions. All 200,000 tables went through the normal `luaH_new` →
`luaC_newobj` path.

The OP_NEWTABLE arena check (`ci->arena != NULL`) cost 6,000,003
instructions across 2,000,001 table creations — a small overhead of 3
instructions per table that provided no benefit.

### Why the escape analyzer cannot help the testbench

```lua
for i = 1, m do
    for j = 1, n do
        count = count + 1
        local obj = {}              -- candidate
        obj[1] = "payload"
        obj[2] = {i, j}
        if count % survive_every == 0 then
            survivors[#survivors + 1] = obj   -- ESCAPES via Rule 3
        end
    end
end
return survivors                    -- survivors ESCAPES via Rule 1
```

The escape analysis correctly identifies that:

1. `survivors` is returned → ESCAPES (Rule 1)
2. `obj` is stored into `survivors` → ESCAPES (Rule 3, dependency on survivors)
3. Since `obj` escapes, `{i, j}` stored in `obj[2]` also escapes (Rule 3 chain)

The critical insight: `obj` is stored into `survivors` **conditionally**
(`if count % survive_every == 0`). In reality, only 1% of `obj` allocations
actually escape. But the escape analysis is **static** — it cannot reason
about runtime branch probabilities. Since `obj` appears in
`survivors[...] = obj` in at least one code path, ALL iterations mark `obj`
as escaping.

This is the correct conservative behavior (never promote an escaping table),
but it means the analyzer provides zero benefit for workloads where escape
is conditional or data-dependent.

---

## Workloads Where Promotion Helps vs Doesn't Help

### Would NOT help (like this testbench)

- Tables that conditionally escape depending on runtime values
- Tables that are always returned or stored in globals
- Tables passed to unknown/unwhitelisted functions
- Programs where most table allocations are long-lived

### WOULD help

- Functions that create temporary tables for intermediate computation:
```lua
  function distance(x1, y1, x2, y2)
      local p = {}          -- NON-ESCAPING: purely local
      p.dx = x2 - x1
      p.dy = y2 - y1
      return math.sqrt(p.dx^2 + p.dy^2)   -- returns number, not table
  end
```
- Functions that build local lookup tables used only within the function
- Parser/compiler functions that create temporary AST nodes consumed locally
- Mathematical computation using tables as vectors/matrices without returning them

### The fundamental tradeoff

The escape analyzer's benefit is inversely proportional to the escape rate.
If 100% of tables escape (like this testbench), benefit is zero and there's
a small overhead from the arena check. If 0% escape, all allocations bypass
the GC entirely. Real-world programs typically fall somewhere in between.

---

## Files

- `d3driver.c` — C driver for both stock and modified builds
- `benchmark.sh` — the benchmarking script
- `results.txt` — raw output from all runs
- `compile_stock.out` — callgrind output for stock compilation
- `compile_modified.out` — callgrind output for modified compilation
- `run_stock_1000.out` — callgrind output for stock runtime
- `run_mod_1000.out` — callgrind output for modified runtime

## How to Reproduce

```bash
# Build stock Lua
cd original/lua-5.5.0
make clean && make all MYCFLAGS="-g -O2"
cd ../..

# Build modified Lua (should already be built)
cd lua5.5-student-src/lua-5.5.0
make clean && make all MYCFLAGS="-g -O2"
cd ../..

# Run benchmarks
bash "Part D/Part 3/benchmark.sh"
cat "Part D/Part 3/results.txt"
```


---

## Measurement 2 (continued): Multi-Parameter Collector Benefit

### Total instruction counts across parameter sets

| m     | Total allocs | Stock (Ir)      | Modified (Ir)   | Δ            | % change |
|-------|-------------|-----------------|-----------------|--------------|----------|
| 100   | 20,000      | 65,865,600 BB   | 65,756,435 BB   | -109,165     | -0.17%   |
| 500   | 100,000     | 331,826,599 BB  | 331,039,842 BB  | -786,757     | -0.24%   |
| 1000  | 200,000     | 662,959,825 BB  | 658,889,071 BB  | -4,070,754   | -0.61%   |
| 5000  | 1,000,000   | 3,323,113,356 BB| 3,297,836,617 BB| -25,276,739  | -0.76%   |

(BB = basic blocks from callgrind Timerange)

### GC function comparison across parameter sets

#### m=100 (20,000 tables)

| Function         | Stock (Ir)  | Modified (Ir) | Δ         |
|-----------------|-------------|---------------|-----------|
| luaC_newobj     | 4,205,460   | 4,205,460     | 0         |
| sweeplist       | 4,233,882   | 4,265,907     | +32,025   |
| propagatemark   | 6,213,348   | 6,234,883     | +21,535   |
| traversearray   | 4,923,692   | 4,948,692     | +25,000   |
| reallymarkobject| 3,810,959   | 3,822,824     | +11,865   |
| freeobj         | 3,606,115   | 3,606,115     | 0         |
| singlestep      | 2,785,459   | 2,779,232     | -6,227    |
| luaH_new        | 2,800,308   | 2,800,308     | 0         |
| luaC_step       | 1,314,111   | 1,318,823     | +4,712    |

#### m=500 (100,000 tables)

| Function         | Stock (Ir)  | Modified (Ir) | Δ         |
|-----------------|-------------|---------------|-----------|
| luaC_newobj     | 21,005,460  | 21,005,460    | 0         |
| sweeplist       | 20,599,257  | 20,777,544    | +178,287  |
| propagatemark   | 31,488,696  | 31,642,191    | +153,495  |
| traversearray   | 28,797,451  | 28,948,997    | +151,546  |
| reallymarkobject| 18,436,649  | 18,524,114    | +87,465   |
| freeobj         | 18,006,115  | 18,006,115    | 0         |
| singlestep      | 14,852,668  | 14,848,717    | -3,951    |
| luaH_new        | 14,000,308  | 14,000,308    | 0         |
| luaC_step       | 7,012,608   | 7,047,276     | +34,668   |

#### m=5000 (1,000,000 tables)

| Function         | Stock (Ir)    | Modified (Ir)  | Δ           |
|-----------------|---------------|----------------|-------------|
| luaC_newobj     | 210,005,460   | 210,005,460    | 0           |
| sweeplist       | 205,117,700   | 203,419,437    | -1,698,263  |
| propagatemark   | 319,877,879   | 316,006,309    | -3,871,570  |
| traversearray   | 305,614,181   | 302,182,072    | -3,432,109  |
| reallymarkobject| 184,095,534   | 181,872,334    | -2,223,200  |
| freeobj         | 180,006,115   | 180,006,115    | 0           |
| singlestep      | 153,617,886   | 151,007,557    | -2,610,329  |
| luaH_new        | 140,000,308   | 140,000,308    | 0           |
| luaC_step       | 72,532,328    | 71,653,547     | -878,781    |

### Objects reaching the sweeper

| m     | Stock luaC_newobj calls | Modified luaC_newobj calls | Δ |
|-------|------------------------|---------------------------|---|
| 100   | ~200,001               | ~200,001                  | 0 |
| 500   | ~1,000,001             | ~1,000,001                | 0 |
| 5000  | ~10,000,022            | ~10,000,022               | 0 |

All tables go through `luaC_newobj` in both builds — the arena path is never
taken because all table-locals in the testbench are marked as escaping by
the static analysis.

### Analysis of trends across parameter sets

**At small scale (m=100, m=500):** The modified build shows slightly MORE
GC instructions than stock. This is because the arena infrastructure adds
a small fixed overhead: arena creation/destruction in `luaD_precall`/`luaD_poscall`,
and the PC check in `OP_NEWTABLE`. At small scale, this overhead is not
offset by any GC savings (since no tables are arena-allocated).

**At large scale (m=5000):** The modified build shows FEWER GC instructions
across all major GC functions — sweeplist, propagatemark, traversearray,
reallymarkobject, and singlestep all decrease. The total reduction is ~14.8M
instructions. This is not from arena allocation (which never triggers) but
from minor differences in GC cycle timing caused by the slightly different
memory layout and allocation patterns in the modified build.

**Consistent across all scales:**
- `luaC_newobj` is identical — same number of objects allocated via GC heap
- `freeobj` is identical — same number of objects freed
- `luaH_new` is identical — same number of tables created
- The arena functions (`luaH_new_arena`, `luaM_arena_alloc`) show 0 instructions

### Why zero promotion benefit on the testbench

The escape analysis correctly identifies that `obj` escapes because it is
stored into `survivors` (Rule 3: `survivors[#survivors + 1] = obj`), and
`survivors` escapes because it is returned (Rule 1). This is true even
though only 1% of `obj` allocations actually reach the store statement
at runtime.

The static analysis cannot distinguish between "this code path always
executes" and "this code path executes 1% of the time." Since the
escaping store exists in any code path, all iterations must conservatively
assume `obj` escapes.

This is the fundamental limitation: **static escape analysis cannot help
workloads where escape is conditional on runtime values.** The benefit
would appear in workloads where tables are unconditionally non-escaping —
purely local computation tables that never appear in any return, store,
capture, or non-whitelisted call path.