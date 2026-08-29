# Part D.2: Benchmarking the Sweep-Step Tuning

## Overview

This benchmark measures the effect of the tunable GCSWEEPMAX parameter
introduced in Part B. GCSWEEPMAX controls how many objects the incremental
GC's sweeper processes per step. We test four values: 5, 20 (default), 50,
and 200.

---

## Results

### (a) Total Instruction Count

| GCSWEEPMAX | Total Instructions | Δ from default | % change |
|------------|-------------------|----------------|----------|
| 5          | 3,397,534,385     | +30,265,152    | +0.90%   |
| 20         | 3,367,269,233     | (baseline)     | —        |
| 50         | 3,361,217,551     | -6,051,682     | -0.18%   |
| 200        | 3,358,202,100     | -9,067,133     | -0.27%   |

Larger GCSWEEPMAX consistently reduces total instruction count. The
relationship shows diminishing returns: the 5→20 jump saves 30.3M
instructions, while 50→200 saves only 3.0M.

### (b) sweeplist Call Distribution

| GCSWEEPMAX | sweeplist calls | sweeplist Ir (instructions) | sweeplist % of total |
|------------|----------------|----------------------------|---------------------|
| 5          | 603,011        | 52,282,930                 | 1.54%               |
| 20         | 151,259        | 40,989,130                 | 1.22%               |
| 50         | 60,911         | 38,730,430                 | 1.15%               |
| 200        | 15,732         | 37,600,955                 | 1.12%               |

With GCSWEEPMAX=5, the sweeper is called 603K times (each processing 5
objects). With GCSWEEPMAX=200, it's called only 15.7K times (each processing
200 objects) — a 38x reduction in call count. The total sweeplist cost drops
from 52.3M to 37.6M instructions, a 28% reduction.

### GC-related function costs (GCSWEEPMAX=5 vs 200)

| Function        | GCSWEEPMAX=5  | GCSWEEPMAX=200 | Difference   |
|-----------------|---------------|----------------|--------------|
| sweeplist       | 52,282,930    | 37,600,955     | -14,681,975  |
| singlestep      | 43,398,642    | 25,780,272     | -17,618,370  |
| luaC_step       | 19,584,488    | 12,544,756     | -7,039,732   |
| propagatemark   | 63,032,663    | 63,032,663     | 0            |
| traversearray   | 58,981,088    | 58,981,088     | 0            |
| reallymarkobject| 36,599,903    | 36,599,903     | 0            |
| freeobj         | 36,006,085    | 36,006,085     | 0            |
| luaC_newobj     | 42,005,439    | 42,005,439     | 0            |

---

## Analysis

### Why larger GCSWEEPMAX reduces total instructions

Each call to `sweepstep()` → `sweeplist()` has a fixed overhead: function
entry, reading the GCSWEEPMAX variable, setting up the loop counter, checking
the sweep pointer, and returning. With GCSWEEPMAX=5, this overhead is paid
603K times. With GCSWEEPMAX=200, it's paid only 15.7K times. The actual
per-object sweep work (checking marks, freeing dead objects) is the same
regardless of batch size — only the call overhead changes.

### Why non-GC functions are unaffected

`luaV_execute`, `luaH_newkey`, `luaH_resize`, `malloc`, `_int_free` all show
identical instruction counts across all four values. GCSWEEPMAX only controls
how sweep work is batched, not how much total sweep work exists or how the
rest of the program runs.

### Why the mark phase is unaffected

`propagatemark`, `traversearray`, and `reallymarkobject` are identical across
all values. This confirms GCSWEEPMAX only affects the sweep phase. The mark
phase runs the same number of cycles and visits the same objects regardless
of how the sweep is batched.

### The throughput vs latency tradeoff

Small GCSWEEPMAX (5): Each sweep step is very short (good for latency-
sensitive applications like games with 60fps frame budgets) but the total
overhead is higher because of frequent function call setup/teardown.

Large GCSWEEPMAX (200): Each sweep step is longer (worse for latency) but
total overhead is lower because function call overhead is amortized over
more objects per call.

For this workload (100K table allocations, batch processing), GCSWEEPMAX=200
is optimal — there's no latency constraint, so minimizing total overhead
is the only goal. For a game engine, GCSWEEPMAX=5 might be preferable
despite the higher total cost, because no single frame would see a long
GC pause.

### Diminishing returns

| Transition | Instructions saved | Marginal gain |
|------------|-------------------|---------------|
| 5 → 20     | 30,265,152        | large         |
| 20 → 50    | 6,051,682         | moderate      |
| 50 → 200   | 3,015,451         | small         |

The biggest win is moving from 5 to 20. Beyond 50, additional increases
provide minimal benefit because the per-call overhead is already amortized
over enough objects that it's no longer the bottleneck.

### Sweep as a fraction of total cost

Even at GCSWEEPMAX=5, sweep-related functions account for only ~1.5% of
total program instructions. The real cost centers are table operations:
`luaH_newkey` (11.3%), `_int_free` (10.4%), `luaH_resize` (9.6%), and
`malloc` (6.6%). This means that for this workload, tuning GCSWEEPMAX
produces a measurable but modest improvement — the dominant costs lie
elsewhere (allocation and table resizing).

---

## Files

- `benchmark.sh` — the benchmarking script
- `results.txt` — raw output from all runs
- `sweep_5.out` — callgrind output for GCSWEEPMAX=5
- `sweep_20.out` — callgrind output for GCSWEEPMAX=20
- `sweep_50.out` — callgrind output for GCSWEEPMAX=50
- `sweep_200.out` — callgrind output for GCSWEEPMAX=200

## How to Reproduce

```bash
cd "Part B"
gcc -g -O2 \
    -I../lua5.5-student-src/lua-5.5.0/src \
    -o sweeptest sweeptest.c \
    ../lua5.5-student-src/lua-5.5.0/src/liblua.a \
    -lm -ldl
bash "../Part D/Part 2/benchmark.sh"
cat "../Part D/Part 2/results.txt"
```