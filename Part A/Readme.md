# Part A - Lua 5.5 Garbage Collector Analysis

##  Overview

The objective of Part A is to understand the stock Lua 5.5.0 garbage collector using the Lua GC source code and Callgrind results, and to compare the Full, Incremental, and Generational configurations.


##  Benchmark

The supplied benchmark uses:

```text
m = 1000
n = 1000
survive_every = 100
```

Therefore, the benchmark executes:

```text
1000 x 1000 = 1,000,000 iterations
```

Each iteration creates:

- one outer table
- one inner table

Every 100th outer object is stored in the `survivors` table. Thus, the workload creates a large number of short-lived objects and a smaller population of longer-lived objects.

This allocation pattern is particularly relevant when comparing the generational collector with the other configurations.

##  GC Configurations

The three executables use the following Lua GC operations:

```text
fullgc          -> lua_gc(L, LUA_GCCOLLECT)
incrementalgc   -> lua_gc(L, LUA_GCINC)
generationalgc -> lua_gc(L, LUA_GCGEN)
```

An important detail is that `LUA_GCCOLLECT` performs a full collection when the call is made. It does not permanently place Lua into a separate full-GC mode.

Therefore, the Full-GC and Incremental results are expected to be relatively close for the workload measured after the wrapper call.

##  Callgrind Measurement

Callgrind reports the number of executed instructions using the `Ir` event.

For the report, the inclusive instruction cost attributed to `luaC_step` is used as the high-level measure of GC work.

The GC instruction percentage is calculated as:

```text
GC instruction percentage =
(inclusive instructions attributed to luaC_step /
 total executed instructions) x 100
```

For the original benchmark, the results are:

| Configuration | Total Instructions | GC Instruction Share |
|---|---:|---:|
| Full | 3,710,041,444 | 23.55% |
| Incremental | 3,700,133,914 | 23.46% |
| Generational | 3,574,116,509 | 20.93% |

##  Main Observations

### Full vs Incremental

The Full and Incremental configurations have almost identical instruction shares:

```text
Full        = 23.55%
Incremental = 23.46%
```

This is consistent with the wrapper implementation. The explicit full collection occurs before the benchmark, while the workload itself continues to execute with normal GC activity.

### Generational

The Generational configuration has the lowest measured GC instruction share:

```text
Generational = 20.93%
```

The call graph also shows much less ordinary propagation work and a significant `sweepgen()` path.

This matches the benchmark's object-lifetime pattern: most allocated objects become unreachable quickly, while only a smaller subset is retained in `survivors`.

### Inclusive Costs

Inclusive Callgrind percentages must not be added together.

For example, the cost reported for:

```text
luaC_step
    -> singlestep
        -> propagatemark
```

is nested. The cost of `propagatemark` is already included in its callers' inclusive costs.

Therefore, the report uses the high-level inclusive cost of `luaC_step` rather than summing the percentages of all nested functions.

##  Important Call-Graph Paths

The main source-level paths discussed in the report are:

```text
luaV_execute -> luaH_new -> luaC_newobj -> luaC_newobjdt -> luaM_malloc_
```

This corresponds to table creation and allocation.

```text
luaV_execute -> luaV_finishset -> luaH_finishset -> luaH_newkey -> luaH_resize
```

This corresponds to table assignments and possible table resizing.

```text
luaC_step -> singlestep -> propagatemark
```

This represents the marking/state-machine side of GC work.

```text
sweeplist -> freeobj -> luaH_free -> luaM_free_
```

This represents object reclamation.

For Generational GC, the important additional path is:

```text
sweepgen -> freeobj
```

which represents generation-aware sweeping and object reclamation.

##  Reproducing the Callgrind Runs

After building the Lua 5.5 library and wrapper executables, a typical Callgrind run is:

```bash
valgrind --tool=callgrind ./fullgc
valgrind --tool=callgrind ./incrementalgc
valgrind --tool=callgrind ./generationalgc
```

The generated `callgrind.out.*` files can then be opened using a Callgrind visualization tool such as KCachegrind/QCachegrind to inspect the call graph and inclusive instruction costs.

##  Conclusion

The main result of Part A is that the measured GC instruction share is:

```text
Full          : 23.55%
Incremental   : 23.46%
Generational  : 20.93%
```

The Generational collector shows lower GC instruction cost for this benchmark and follows a noticeably different call-graph path, with substantially fewer ordinary propagation steps and significant generation-aware sweeping.

The results are interpreted together with the Lua 5.5 GC source code and the benchmark's short-lived/long-lived object pattern.
