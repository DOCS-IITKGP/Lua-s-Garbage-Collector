# Part D.2: Benchmarking the Sweep-Step Tuning

## Overview

This benchmark measures the effect of the tunable GCSWEEPMAX parameter
introduced in Part B. GCSWEEPMAX controls how many objects the incremental
GC's sweeper processes per step. We test four values: 5, 20 (default), 50,
and 200, on the testbench from Appendix A (m=1000, n=100).

---

## Results

### (a) Total Instruction Count

| GCSWEEPMAX | Total Instructions | Δ from default | % change |
|------------|-------------------|----------------|----------|
| 5          | 340,179,545       | +3,155,985     | +0.94%   |
| 20         | 337,023,560       | (baseline)     | —        |
| 50         | 336,394,501       | -629,059       | -0.19%   |
| 200        | 336,084,715       | -938,845       | -0.28%   |

Larger GCSWEEPMAX consistently reduces total instruction count. The
relationship shows diminishing returns: the 5→20 jump saves 3.16M
instructions, while 50→200 saves only 310K.

### (b) Sweep-Phase Step Costs (GCSswpallgc)

| GCSWEEPMAX | sweeplist (instrs) | sweeplist % of total | freeobj (instrs) | luaC_step (instrs) |
|------------|-------------------|---------------------|-----------------|-------------------|
| 5          | 5,470,214         | 1.61%               | 3,606,085       | 1,894,752         |
| 20         | 4,292,664         | 1.27%               | 3,606,085       | 1,329,752         |
| 50         | 4,057,214         | 1.21%               | 3,606,085       | 1,217,240         |
| 200        | 3,939,389         | 1.17%               | 3,606,085       | 1,163,708         |

`sweeplist` cost drops from 5.47M to 3.94M instructions across the
5→200 range — a 28% reduction. `freeobj` remains constant at 3,606,085
instructions across all values, confirming that the total sweep work
(number of objects freed) is invariant to granularity. Only the overhead
of entering and exiting `sweeplist` changes.

---

## Analysis

### Why larger GCSWEEPMAX reduces total instructions

Each call to `sweepstep()` → `sweeplist()` has a fixed overhead: function
entry, reading the GCSWEEPMAX variable, setting up the loop counter,
checking the sweep pointer, and returning. With GCSWEEPMAX=5, this
overhead is paid many more times than with GCSWEEPMAX=200. The actual
per-object sweep work (checking marks, freeing dead objects) is the same
regardless of batch size — only the call overhead changes.

### freeobj invariance confirms total work is preserved

`freeobj` is identical (3,606,085) across all four values. This is the
key finding: sweep-step tuning only affects how work is *distributed*
across incremental steps, not the total volume of work. The same number
of objects are allocated, marked, and freed regardless of GCSWEEPMAX.

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
| 5 → 20     | 3,155,985         | large         |
| 20 → 50    | 629,059           | moderate      |
| 50 → 200   | 309,786           | small         |

The biggest win is moving from 5 to 20. Beyond 50, additional increases
provide minimal benefit because the per-call overhead is already amortized
over enough objects that it's no longer the bottleneck.

---

## Files

- `d2_results.txt` — benchmark results
- `READMED2.md` — this report

## How to Reproduce

```bash
cd "Part B"

# Build Lua with Part B patches
cd lua-5.5.0
make clean && make all MYCFLAGS="-g -O2"
cd ..

# Compile sweeptest
gcc -g -O2 -I lua-5.5.0/src -o sweeptest sweeptest.c lua-5.5.0/src/liblua.a -lm -ldl

# Run benchmarks
for val in 5 20 50 200; do
    echo "=== GCSWEEPMAX = $val ==="
    valgrind --tool=callgrind --callgrind-out-file=sweep_${val}.out ./sweeptest $val
    callgrind_annotate sweep_${val}.out | grep -E "PROGRAM TOTALS|sweeplist|freeobj|luaC_step"
done
```