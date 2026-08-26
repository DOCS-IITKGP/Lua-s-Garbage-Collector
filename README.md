"# Lua-s-Garbage-Collector" 
# Assignment 1: Understanding, Tuning, and Extending Lua's Garbage Collector

## Overview

This assignment explores Lua 5.5's garbage collector end to end across four parts:

- **Part A**: Profile the three GC configurations (full, incremental, generational)
  using Valgrind/callgrind and understand their internal function call patterns.
- **Part B**: Turn the hardcoded sweep granularity constant `GCSWEEPMAX` into a
  runtime-tunable parameter by modifying `lgc.c` and `lua.h`.
- **Part C**: Implement a static escape analyzer and frame-arena allocator so that
  provably non-escaping table allocations bypass the GC heap entirely.
- **Part D**: Benchmark all of the above together in a consolidated comparison.

---

## Important: How the Lua Source Works in This Repo

The full Lua source tree (`lua-5.5.0/`) is NOT tracked in git because it is
reproducible from the provided zip file. Only the **changed files** for each
part are tracked, under `Part X/src/`.

The workflow for anyone reproducing this is:

1. Unzip the provided source
2. Apply the patch for the relevant part
3. Rebuild Lua
4. Compile and run the part's driver

This keeps the repo clean while making every change fully auditable via the
diffs and copied modified files.

---

## Prerequisites

```bash
sudo apt update
sudo apt install build-essential valgrind python3-pip graphviz
pip3 install gprof2dot
```

---

## Step 0: Extract and Build Unmodified Lua (Do This First)

```bash
unzip lua5.5-student-src.zip
cd lua-5.5.0
make all MYCFLAGS="-g -O2"
./src/lua -v    # should print: Lua 5.5.0
cd ..
```

This gives you a clean baseline. Each part's instructions below tell you
exactly what to change before rebuilding.

---

## Part A: GC Profiling

### What it does
Three C drivers load `testbench.lua` under full, incremental, and generational
GC configurations. Valgrind/callgrind profiles each run to produce call graphs
showing which internal GC functions are called, how often, and in what order.

### No source changes needed for Part A
Part A uses the unmodified Lua build from Step 0.

### Files
Part A/
├── fullgc.c ← full GC driver (LUA_GCCOLLECT)
├── incrementalgc.c ← incremental GC driver (LUA_GCINC)
├── generationalgc.c ← generational GC driver (LUA_GCGEN)
├── testbench.lua ← workload
└── README.md ← report (≤5 pages)


### How to reproduce

```bash
cd "Part A"

# Compile all three drivers against the unmodified Lua build
gcc -g -O2 -I../lua-5.5.0/src \
    -o fullgc fullgc.c \
    ../lua-5.5.0/src/liblua.a -lm -ldl

gcc -g -O2 -I../lua-5.5.0/src \
    -o incrementalgc incrementalgc.c \
    ../lua-5.5.0/src/liblua.a -lm -ldl

gcc -g -O2 -I../lua-5.5.0/src \
    -o generationalgc generationalgc.c \
    ../lua-5.5.0/src/liblua.a -lm -ldl

# Profile with callgrind
valgrind --tool=callgrind --callgrind-out-file=callgrind_full.out ./fullgc
valgrind --tool=callgrind --callgrind-out-file=callgrind_inc.out ./incrementalgc
valgrind --tool=callgrind --callgrind-out-file=callgrind_gen.out ./generationalgc

# Generate call graph images
gprof2dot -f callgrind callgrind_full.out | dot -Tpng -o fullgc_callgraph.png
gprof2dot -f callgrind callgrind_inc.out  | dot -Tpng -o incrementalgc_callgraph.png
gprof2dot -f callgrind callgrind_gen.out  | dot -Tpng -o generationalgc_callgraph.png
```

---

## Part B: Tunable Sweep Granularity

### What it does
`GCSWEEPMAX` in `lgc.c` was a hardcoded constant (value: 20) controlling how
many objects `sweepstep()` frees per incremental GC step. It is now a
`static int` variable exposed via a new `setsweepstep()` function.

### Changes made
- `lgc.c` line 34: `#define GCSWEEPMAX 20` → `static int GCSWEEPMAX = 20;`
- `lgc.c` end of file: added `setsweepstep()` function
- `lua.h` line 361: added `setsweepstep()` declaration

Modified files are in `Part B/src/` for reference.
Diffs are in `Part B/lgc.c.patch` and `Part B/lua.h.patch`.

### How to reproduce

```bash
# Step 1: apply changes to the extracted Lua source
# Option A — apply the patch directly
cd lua-5.5.0
patch -p1 src/lgc.c < "../Part B/lgc.c.patch"
patch -p1 src/lua.h < "../Part B/lua.h.patch"

# Option B — manually copy the modified files
cp "Part B/src/lgc.c" lua-5.5.0/src/lgc.c
cp "Part B/src/lua.h" lua-5.5.0/src/lua.h

# Step 2: rebuild Lua with the changes
cd lua-5.5.0
make clean && make all MYCFLAGS="-g -O2"
./src/lua -v    # should still print: Lua 5.5.0

# Step 3: compile and run the test driver
cd "../Part B"
gcc -g -O2 \
    -I../lua-5.5.0/src \
    -o sweeptest sweeptest.c \
    ../lua-5.5.0/src/liblua.a \
    -lm -ldl

./sweeptest 5
./sweeptest 20
./sweeptest 50
./sweeptest 200
```

---

## Part C: Static Escape Analysis
Part 1 (Done)
Part 2 (Coming)

## Part D: Benchmarking (coming)