# Assignment 1: Understanding, Tuning, and Extending Lua's Garbage Collector

## Overview

This assignment explores Lua 5.5's garbage collector end to end across four parts:

- **Part A**: Profile the three GC configurations (full, incremental, generational)
  using Valgrind/callgrind and understand their internal function call patterns.
- **Part B**: Turn the hardcoded sweep granularity constant `GCSWEEPMAX` into a
  runtime-tunable parameter by modifying `lgc.c` and `lua.h`.
- **Part C**: Implement a static escape analyzer (C.1) and frame-arena allocator
  (C.2) so that provably non-escaping table allocations bypass the GC heap entirely.
- **Part D**: Benchmark all of the above together in a consolidated comparison.

---

## How the Lua Source Works in This Repo

The full Lua source tree is NOT tracked in git — it's reproducible from the
provided zip file. Only **changed files** are tracked under `Part X/src/`,
with diffs under `Part X/patch/`.

To reproduce: unzip → copy modified files (or apply patches) → rebuild → run.

---

## Repository Structure

```
Assignment 1/
├── README.md ← this file
├── lua5.5-student-src.zip ← original provided Lua 5.5.0 source
├── testbench.lua ← shared workload (m=1000, n=100)
│
├── Part A/ ← GC profiling (friend's work)
│ ├── fullgc.c ← full GC driver (LUA_GCCOLLECT)
│ ├── incrementalgc.c ← incremental GC driver (LUA_GCINC)
│ ├── generationalgc.c ← generational GC driver (LUA_GCGEN)
│ ├── testbench.lua
│ ├── fullgc.png ← call graph images
│ ├── incrementalgc.png
│ ├── generationalgc.png
│ └── callgrind.out.* ← callgrind outputs
│
├── Part B/ ← tunable sweep granularity
│ ├── src/
│ │ ├── lgc.c ← modified (GCSWEEPMAX + setsweepstep)
│ │ └── lua.h ← modified (setsweepstep declaration)
│ ├── patch/
│ │ ├── lgc.c.patch
│ │ └── lua.h.patch
│ ├── sweeptest.c ← C driver for testing sweep values
│ ├── testbench.lua
│ └── READMEB.md
│
├── Part C/
│ ├── Part 1/ ← escape analysis (C.1)
│ │ ├── src/
│ │ │ ├── lparser.c ← modified (7 hooks for 4 escape rules)
│ │ │ ├── lparser.h ← modified (Vardesc + FuncState fields)
│ │ │ └── llex.h ← modified (LexState fields)
│ │ ├── patch/
│ │ │ ├── lparser.c.patch
│ │ │ ├── lparser.h.patch
│ │ │ └── llex.h.patch
│ │ ├── test_escape.lua ← basic 6-case test
│ │ ├── test_escape_full.lua ← comprehensive 13-case test
│ │ └── READMEC1.md
│ │
│ └── Part 2/ ← frame-arena allocation (C.2)
│ ├── src/
│ │ ├── lmem.h ← FrameArena struct + declarations
│ │ ├── lmem.c ← arena_new, arena_alloc, arena_free
│ │ ├── lobject.h ← Proto: arena_pcs[], num_arena_pcs
│ │ ├── ltable.h ← luaH_new_arena declaration
│ │ ├── ltable.c ← luaH_new_arena implementation
│ │ ├── lstate.h ← CallInfo: arena pointer
│ │ ├── lstate.c ← arena=NULL init in extendCI/resetCI
│ │ ├── lvm.c ← OP_NEWTABLE arena check
│ │ ├── ldo.c ← arena create/destroy on call/return
│ │ ├── lfunc.c ← arena_pcs init/free in Proto
│ │ ├── lparser.c ← PC tracking + close_func PC storage
│ │ ├── lparser.h ← newtable_pc field in Vardesc
│ │ └── llex.h ← last_constructor_pc field
│ ├── patch/
│ │ ├── lmem.h.patch, lmem.c.patch
│ │ ├── lobject.h.patch
│ │ ├── ltable.h.patch, ltable.c.patch
│ │ ├── lstate.h.patch, lstate.c.patch
│ │ ├── lvm.c.patch, ldo.c.patch, lfunc.c.patch
│ │ ├── lparser.c.patch, lparser.h.patch
│ │ └── llex.h.patch
│ └── READMEC2.md
│
├── Part D/
│ ├── Part 1/ ← D.1: stock GC benchmarking (friend's work)
│ │
│ ├── Part 2/ ← D.2: sweep-step tuning benchmarks
│ │ ├── benchmark.sh
│ │ ├── results.txt
│ │ ├── sweep_5.out, sweep_20.out, sweep_50.out, sweep_200.out
│ │ └── READMED2.md
│ │
│ └── Part 3/ ← D.3: escape analyzer cost/benefit
│ ├── d3driver.c
│ ├── benchmark.sh
│ ├── benchmark_params.sh
│ ├── results.txt ← compile-time + default runtime
│ ├── results_params.txt ← multi-parameter runtime
│ ├── compile_stock.out, compile_modified.out
│ ├── run_stock_.out, run_mod_.out
│ ├── testbench_100.lua, testbench_500.lua, testbench_5000.lua
│ └── READMED3.md
│
└── original/ ← unmodified Lua for diffing (gitignored)
```


---

## Prerequisites

```bash
sudo apt update
sudo apt install build-essential valgrind python3-pip graphviz
pip3 install gprof2dot
```

---

## Step 0: Extract and Build Unmodified Lua

```bash
unzip lua5.5-student-src.zip
cd lua-5.5.0
make all MYCFLAGS="-g -O2"
./src/lua -v    # should print: Lua 5.5.0
cd ..
```

---

## Part A: GC Profiling

Three C drivers load `testbench.lua` under full, incremental, and generational
GC. Valgrind/callgrind produces call graphs showing internal GC behavior.

**Deliverables:** Three C files, call graph images, callgrind outputs, report (≤5 pages).

```bash
cd "Part A"
gcc -g -O2 -I../lua-5.5.0/src -o fullgc fullgc.c ../lua-5.5.0/src/liblua.a -lm -ldl
gcc -g -O2 -I../lua-5.5.0/src -o incrementalgc incrementalgc.c ../lua-5.5.0/src/liblua.a -lm -ldl
gcc -g -O2 -I../lua-5.5.0/src -o generationalgc generationalgc.c ../lua-5.5.0/src/liblua.a -lm -ldl

valgrind --tool=callgrind --callgrind-out-file=callgrind_full.out ./fullgc
valgrind --tool=callgrind --callgrind-out-file=callgrind_inc.out ./incrementalgc
valgrind --tool=callgrind --callgrind-out-file=callgrind_gen.out ./generationalgc

gprof2dot -f callgrind callgrind_full.out | dot -Tpng -o fullgc.png
gprof2dot -f callgrind callgrind_inc.out  | dot -Tpng -o incrementalgc.png
gprof2dot -f callgrind callgrind_gen.out  | dot -Tpng -o generationalgc.png
```

---

## Part B: Tunable Sweep Granularity

`GCSWEEPMAX` in `lgc.c` converted from `#define 20` to `static int` with
runtime setter `setsweepstep()`. See `Part B/READMEB.md` for details.

**Deliverables:** Modified lgc.c, lua.h, diffs, README.

```bash
cp "Part B/src/lgc.c" lua-5.5.0/src/
cp "Part B/src/lua.h" lua-5.5.0/src/
cd lua-5.5.0 && make clean && make all MYCFLAGS="-g -O2" && cd ..

cd "Part B"
gcc -g -O2 -I../lua-5.5.0/src -o sweeptest sweeptest.c ../lua-5.5.0/src/liblua.a -lm -ldl
./sweeptest 5 && ./sweeptest 20 && ./sweeptest 50 && ./sweeptest 200
```

---

## Part C.1: Static Escape Analysis

Compile-time analyzer that marks `local t = {}` allocations as escaping or
non-escaping based on four rules: return, capture, store, call.
See `Part C/Part 1/READMEC1.md` for design details.

**Deliverables:** Modified lparser.c, lparser.h, llex.h, diffs, design note.

```bash
# Copy C.1 files and rebuild
for f in Part\ C/Part\ 1/src/*; do cp "$f" lua-5.5.0/src/; done
cd lua-5.5.0 && make clean && make all MYCFLAGS="-g -O2"

# Verify escape analysis
./src/lua "Part C/Part 1/test_escape_full.lua"
```

---

## Part C.2: Frame-Arena Promotion

For non-escaping tables, allocates from a per-call-frame bump arena instead
of the GC heap. Arena freed in bulk on function return.
See `Part C/Part 2/READMEC2.md` for design details.

**Deliverables:** Modified lgc.c, lmem.c/h, lobject.h, ltable.c/h, lstate.c/h,
lvm.c, ldo.c, lfunc.c, lparser.c/h, llex.h, diffs, README.

```bash
# Copy ALL C.2 files (includes C.1 changes) and rebuild
for f in Part\ C/Part\ 2/src/*; do cp "$f" lua-5.5.0/src/; done
cd lua-5.5.0 && make clean && make all MYCFLAGS="-g -O2"

# Verify
./src/lua -v
./src/lua testbench.lua
```

---

## Part D.1: Stock GC Benchmarking

Benchmarks full, incremental, and generational GC across multiple parameter
sets (m=100, 500, 5000) with callgrind and perf.

**Deliverables:** Results, explanations, call graph images, callgrind outputs.

---

## Part D.2: Sweep-Step Tuning Benchmarks

Benchmarks GCSWEEPMAX at values 5, 20, 50, 200 under callgrind.
See `Part D/Part 2/READMED2.md` for analysis.

**Deliverables:** Benchmarking results for every tested sweep-step value.

```bash
cd "Part B"
bash "../Part D/Part 2/benchmark.sh"
cat "../Part D/Part 2/results.txt"
```

---

## Part D.3: Escape Analyzer Cost/Benefit

Two separate measurements: compile-time overhead of C.1 analysis, and
runtime GC benefit of C.1+C.2 across parameter sets.
See `Part D/Part 3/READMED3.md` for analysis.

**Deliverables:** Cost/benefit numbers, explanation of workloads where
promotion helps little or not at all.

```bash
bash "Part D/Part 3/benchmark.sh"
bash "Part D/Part 3/benchmark_params.sh"
cat "Part D/Part 3/results.txt"
cat "Part D/Part 3/results_params.txt"
```

---

## Summary of Changes Across All Parts

| Part | Files Modified | Comment Marker | Key Change |
|------|---------------|----------------|------------|
| B    | lgc.c, lua.h  | `Part B:`      | GCSWEEPMAX tunable |
| C.1  | lparser.c, lparser.h, llex.h | `C.1:` | Escape analysis (4 rules) |
| C.2  | lmem.c/h, lobject.h, ltable.c/h, lstate.c/h, lvm.c, ldo.c, lfunc.c, lparser.c/h, llex.h | `C.2:` | Frame-arena allocation |

All changes are cumulative — Part C.2 includes Part C.1 and Part B changes.
The `Part C/Part 2/src/` folder contains the final state of all modified files.