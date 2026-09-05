# Part B: Sweep Granularity: Making It Tunable

## Overview

Lua 5.5's incremental garbage collector uses a hardcoded constant `GCSWEEPMAX`
(defined in `lgc.c`) to control how many objects the sweeper processes per
incremental step. This constant was set to 20 and could not be changed without
recompiling the interpreter.

In Part B, we turn this constant into a runtime-tunable parameter by replacing
the `#define` with a `static int` variable and exposing a setter function.

## What is GCSWEEPMAX?

During incremental GC, the sweep phase is broken into small steps. Each step
calls `sweepstep()`, which iterates over allocated objects, freeing dead ones
and clearing marks on live ones. `GCSWEEPMAX` is the loop bound, i.e it controls
how many objects are processed per step before yielding back to the program.

- Small values (e.g. 5): short pauses, more frequent steps, higher total overhead
- Large values (e.g. 200): longer pauses, fewer steps, lower total overhead

This is a classic throughput vs latency tradeoff. The optimal value depends on
the workload, which is why we are going to make it tunable. 

## Files Modified

### lgc.c (2 changes)

**Change 1 => Line 34:** Replaced the compile-time constant with a runtime variable.

```c
// BEFORE
#define GCSWEEPMAX  20

// AFTER
static int GCSWEEPMAX = 20;  /* default; tunable via setsweepstep() */
```

The `static` keyword keeps the variable file-scoped (only visible inside lgc.c),
preserving encapsulation. The default value of 20 is unchanged, so unpatched
behavior is identical.

**Change 2 => End of file:** Added a setter function.

```c
void setsweepstep (lua_State *L, int n) {
    (void)L;
    GCSWEEPMAX = (n <= 0) ? 20 : n;
}
```

The `(void)L` suppresses the unused-parameter
warning while keeping the lua_State* argument to follow Lua API conventions.

### lua.h (1 change)

**After line 360 (next to lua_gc declaration):** Added the function declaration.

```c
void setsweepstep (lua_State *L, int n);
```

## API Used

```c
void setsweepstep(lua_State *L, int n);
```

| Parameter | Description |
|-----------|-------------|
| L         | Lua state (follows Lua API convention, currently unused) |
| n         | Max objects swept per incremental step. Values <= 0 reset to default (20). |

## Usage Example

```c
lua_State *L = luaL_newstate();
luaL_openlibs(L);

lua_gc(L, LUA_GCINC, 0, 0, 0);    // enable incremental GC
setsweepstep(L, 50);              // sweep 50 objects per step

luaL_dofile(L, "testbench.lua");
lua_close(L);
```

## How to Build and Test

```bash
# Rebuild Lua with the modified source
cd lua-5.5.0
make clean
make all MYCFLAGS="-g -O2"

# Compile the test driver
cd ../Part\ B
gcc -g -O2 \
  -I../lua5.5-student-src/lua-5.5.0/src \
  -o sweeptest sweeptest.c \
  ../lua5.5-student-src/lua-5.5.0/src/liblua.a \
  -lm -ldl

# Run with different sweep values
./sweeptest 5
./sweeptest 20
./sweeptest 50
./sweeptest 200
```

All runs should print "Testbench completed successfully". The behavioral output
is identical across values, i.e only the internal GC step distribution changes,
which is measured in Part D using callgrind.

## Design Rationale

- **Static variable** keeps the change local to lgc.c with no global state leakage.
- **Default value unchanged** so the patch is backward-compatible.
- lua_State parameter follows Lua API conventions for future per-state tuning.
- **Minimal diff**: only 2 files changed, 3 lines modified/added in lgc.c,
  1 line added in lua.h. The rest of the GC code is untouched.

## Deliverables

- `src/lgc.c` — modified source with comment at top
- `src/lua.h` — modified source with comment at top
- `lgc.c.patch` — unified diff against original
- `lua.h.patch` — unified diff against original
- `sweeptest.c` — C driver program
- `README.md` — this file