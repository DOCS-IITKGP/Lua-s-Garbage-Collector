# Part D.1 - Stock GC Benchmarking

## Overview

This folder contains the submission material for **Part D.1: Benchmarking the Stock GC Configurations** of Design Optimization of Computing Systems Assignment 1.

The experiment benchmarks Lua 5.5's:

- Full GC
- Incremental GC
- Generational GC
- No-GC baseline

The work is divided into the three sub-parts required by the assignment:

1. Callgrind instruction analysis
2. Workload-size analysis
3. `perf` hardware-counter analysis

## Main Files

- `D1_Stock_GC_Benchmarking_Report_Final.pdf` - Main written report containing explanations, results, calculations, comparisons, and conclusion.
- `D1_Stock_GC_Benchmarking_Report_Final.tex` - LaTeX source of the report.
- `README_D1.md` - This README.
- Callgrind call-graph images - submitted separately.
- Raw Callgrind output files - submitted separately.
- `perf` terminal output/results - submitted as supporting evidence.

The report intentionally does **not** embed the call-graph images or raw Callgrind outputs. They are supplied separately as required evidence.

## 1. Assignment Requirements Covered

### D.1(a) Callgrind

The report:

- benchmarks Full, Incremental, and Generational GC;
- reports the percentage of instructions associated with GC;
- explains the variation between configurations;
- explains the important Callgrind execution paths.

The original workload is:

```text
m = 1000
n = 1000
survive_every = 100
```

This gives 1,000,000 loop iterations and approximately 2,000,000 allocated tables.

The GC instruction share is calculated from the inclusive `luaC_step` instruction cost:

```text
GC instruction share =
(inclusive instructions of luaC_step /
 total executed instructions) x 100
```

For nested functions such as `singlestep`, `propagatemark`, `atomic`, and `sweepgen`, their inclusive costs are already contained in parent call paths, so they are not added separately.

### D.1(b) Workload Scaling

The benchmark is repeated for:

```text
m = 100,  n = 100
m = 500,  n = 100
m = 5000, n = 100
```

Measured GC instruction shares:

| Workload | Full | Incremental | Generational |
|---|---:|---:|---:|
| 100 x 100 | 22.48% | 22.13% | 20.19% |
| 500 x 100 | 23.02% | 23.25% | 20.67% |
| 5000 x 100 | 23.38% | 23.36% | 20.84% |

The report explains that the GC share increases slightly because both application and GC instruction counts grow. Generational GC remains the lowest across all three sizes.

### D.1(c) perf

The original `m=1000, n=1000` workload is measured for:

- Full GC
- Incremental GC
- Generational GC
- No GC (`LUA_GCSTOP`)

Reported metrics:

- Branch Misses
- Cache Misses
- Page Faults
- Instructions
- Cycles
- IPC

Measured values:

| Metric | Full | Incremental | Generational | No GC |
|---|---:|---:|---:|---:|
| Branch misses | 83,559 | 81,319 | 93,655 | 40,890 |
| Cache misses | 43,652 | 43,982 | 29,758 | 463,476 |
| Page faults | 223 | 226 | 202 | 4,772 |
| Instructions | 372,688,637 | 372,665,431 | 358,850,300 | 412,773,951 |
| Cycles | 103,583,937 | 102,383,389 | 93,890,933 | 134,658,347 |
| IPC | 3.60 | 3.64 | 3.82 | 3.06 |

The report explains why each metric is relevant and why the values vary.

## 2. Important Experimental Note

The supplied Full-GC wrapper uses:

```c
lua_gc(L, LUA_GCCOLLECT);
```

before executing the testbench.

This performs one full collection at that point. It does not create a permanent Full-GC mode for the whole benchmark.

Therefore, the close Full/Incremental results are interpreted as an effect of the experimental setup and should not be taken to mean that Full and Incremental GC are identical algorithms.

## 3. Main Results

For the original workload:

```text
Full          : 23.55% GC instruction share
Incremental   : 23.46% GC instruction share
Generational  : 20.93% GC instruction share
```

Generational GC is lowest for all three tested workload sizes.

In the `perf` experiment, Generational also has:

- the lowest instruction count among GC-enabled modes;
- the lowest cycle count among GC-enabled modes;
- the lowest cache-miss count among GC-enabled modes;
- the lowest page-fault count among GC-enabled modes;
- the highest IPC.

No GC has fewer branch misses, but it has much larger memory-related costs, including 463,476 cache misses and 4,772 page faults.

## 4. Supporting Evidence to Submit

The assignment requires the report plus experimental evidence.

Include the following separately:

### Callgrind graphs

- Full GC call graph
- Incremental GC call graph
- Generational GC call graph

### Raw Callgrind outputs

Include the raw `callgrind.out.*` files for the required workload runs.

For the three D.1(b) parameter sets, keep the outputs for all three GC configurations:

```text
100 x 100:
    Full
    Incremental
    Generational

500 x 100:
    Full
    Incremental
    Generational

5000 x 100:
    Full
    Incremental
    Generational
```

Also include the original `1000 x 1000` Callgrind outputs used for D.1(a).

### perf evidence

Include the terminal output or captured result for:

```text
Full
Incremental
Generational
No GC
```

## 5. Reproducing the Callgrind Runs

After building the Lua 5.5 wrappers, a typical run is:

```bash
valgrind --tool=callgrind ./fullgc
valgrind --tool=callgrind ./incrementalgc
valgrind --tool=callgrind ./generationalgc
```

Repeat after changing `m` and `n` in `testbench.lua` for the three D.1(b) parameter sets.

The generated `callgrind.out.*` files can be inspected with KCachegrind or QCachegrind to obtain inclusive instruction costs and call graphs.

## 6. Reproducing the perf Run

For each executable, use:

```bash
perf stat -e branches,branch-misses,cache-references,cache-misses,page-faults,instructions,cycles ./fullgc
```

Run the equivalent command for:

```text
incrementalgc
generationalgc
nogc
```

IPC is calculated as:

```text
IPC = Instructions / Cycles
```

## 7. Final Interpretation

For the supplied allocation-heavy benchmark, Generational GC gives the most favorable overall measured behaviour. Full and Incremental remain very close, while No GC shows substantially higher memory-system costs.

These conclusions are specific to this testbench and should not be interpreted as a universal ranking of Lua GC strategies.

