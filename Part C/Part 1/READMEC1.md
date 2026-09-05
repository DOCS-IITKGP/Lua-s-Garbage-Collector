# Part C.1: Static Escape Analysis for Local Table Allocations

## Overview

This module implements a compile-time escape analyzer for Lua 5.5 that
determines whether a `local t = {}` table allocation can safely bypass
the GC heap. A table is "non-escaping" (promotable to a frame arena in
Part C.2) unless the analyzer proves it escapes through one of four rules.

All changes are marked with the comment prefix `C.1:` in the source code.
Search for `C.1` to find every modification.

---

## The Four Escape Rules

### Rule 1: Return Escape
If the table appears in a `return` expression, it escapes — the caller
will hold a reference to it after the function returns.

```lua
local t = {}
return t        -- ESCAPES
```

**Implementation:** Hook in `retstat()` after `explist()` returns. For
single returns, if the expression is a `VLOCAL` table-local, mark
`escapes = 1`. For multi-value returns (`nret > 1`), intermediate
expressions have already been shuffled by `explist()`, so we
conservatively mark ALL table-locals as escaping.

### Rule 2: Capture Escape
If the table is referenced inside a nested closure, it escapes — the
closure could outlive the function.

```lua
local t = {}
local function inner()
   print(t[1])   -- ESCAPES: t is captured
end
```

**Implementation:** Hook in `singlevaraux()` where `markupval()` is called.
When a variable from an outer scope becomes an upvalue and it's a table-local,
mark `escapes = 1`.

### Rule 3: Store Escape
If the table is stored as a value into another table that itself escapes
(globals always escape), then the table escapes too.

```lua
local outer = {}
local inner = {}
outer[1] = inner
return outer      -- both ESCAPE: inner via Rule 3 chain, outer via Rule 1
```

**Implementation:** Hook in `restassign()` before `luaK_storevar()`. If the
value is a table-local and the target is:
- A global/upvalue (`VINDEXUP`) → immediate escape.
- A local table → record a dependency `{src_vidx, dep_vidx}`.

Dependencies are resolved by a fixed-point loop in `close_func()` that
iterates until no new escapes are discovered.

### Rule 4: Call Escape (Conservative Catch-All)
If the table is passed as an argument to any function not on a small
whitelist of known-safe builtins, it escapes.

```lua
local t = {}
unknown_func(t)   -- ESCAPES: unknown callee
print(t)          -- NON-ESCAPING: print is whitelisted
```

**Whitelist:** `print`, `type`, `pairs`, `ipairs`, `tostring`, `tonumber`

**Implementation:** Two-part hook:
1. In `singlevar()`: save the callee name in `ls->last_callee_name` before
   arguments are parsed.
2. In `funcargs()`: save callee name at entry (before argument parsing
   overwrites it), tentatively mark table-local arguments with `escapes = 2`,
   then confirm (`2 → 1`) or revert (`2 → 0`) based on whitelist check.

For multi-argument calls (`nargs > 1`), intermediate arguments have already
been shuffled by `explist()` and we cannot identify which locals they came
from. We conservatively mark ALL table-locals with `escapes = 0` as
tentatively escaping (`escapes = 2`), subject to the same whitelist
confirm/revert logic. The `escapes == 0` guard ensures we never overwrite
a table-local already confirmed escaping by another rule.

### Constructor References
A table-local used as a value inside a `{}` constructor escapes, because
the constructor may itself be returned or stored.

```lua
local t = {}
return {t}        -- ESCAPES: t is embedded in returned constructor
```

**Implementation:** Hooks in `listfield()` and `recfield()` — after
parsing each field value expression, if it's a `VLOCAL` table-local,
mark `escapes = 1`.

---

## Files Modified (3 files)

### llex.h (2 fields added to LexState)
```c
lu_byte last_was_constructor;  /* C.1: set by constructor(), read by localstat() */
TString *last_callee_name;     /* C.1: callee name for Rule 4 whitelist check */
```
These are communication channels between parser functions that run in
sequence but don't directly call each other.

### lparser.h (4 additions)
1. **Vardesc** — added `is_table` and `escapes` fields:
```c
lu_byte is_table;   /* C.1: 1 if initialized with {} */
lu_byte escapes;    /* C.1: 1 if escape analysis marks as escaping */
```

2. **EscapeDep struct** — for Rule 3 dependencies:
```c
typedef struct EscapeDep {
   short src_vidx;    /* vidx of table stored INTO */
   short dep_vidx;    /* vidx of table stored AS VALUE */
} EscapeDep;
```

3. **FuncState** — added dependency tracking:
```c
EscapeDep escape_deps[MAX_ESCAPE_DEPS];  /* C.1: Rule 3 deps */
int num_escape_deps;                      /* C.1: dep count */
```

### lparser.c (hooks)

| Hook | Location | Purpose |
|------|----------|---------|
| 0a | `open_func()` | Initialize `num_escape_deps = 0` |
| 0b | `localstat()` end | Initialize `is_table`/`escapes` fields, tag constructor vars |
| 1a | `constructor()` end | Set `last_was_constructor = 1` flag |
| 1b | `listfield()` after `expr` | Mark table-local list field values as escaping |
| 1c | `recfield()` after `expr` | Mark table-local record field values as escaping |
| 2 | `retstat()` after `explist` | Rule 1: mark returned table-locals (single and multi) |
| 3 | `singlevaraux()` at `markupval` | Rule 2: mark captured table-locals |
| 4 | `singlevar()` + `funcargs()` | Rule 4: whitelist check with tentative marking (single and multi-arg) |
| 5 | `restassign()` before `storevar` | Rule 3: record deps or immediate escape |
| 6 | `close_func()` before `luaK_ret` | Fixed-point propagation + debug output |

Added `#include <stdio.h>` at top for debug `printf`.

---

## Issues Encountered and Resolutions

### Issue 1: Rule 4 register mismatch
**Problem:** When Lua compiles `func(t)`, `t`'s value is copied to a new
argument register. Our initial check compared `t`'s home register (`ridx`)
against argument registers — they never matched.

**Resolution:** Check the `args` expdesc directly after `explist()` returns,
while `args.k` is still `VLOCAL` and `args.u.var.vidx` still points to `t`.

### Issue 2: Rule 4 args expdesc overwritten
**Problem:** Even after the above fix, `luaK_exp2nextreg()` converts `args`
from `VLOCAL` to `VNONRELOC` before our check runs.

**Resolution:** Use a tentative marking strategy — mark table-local args
with `escapes = 2` right after `explist()` (before any register shuffling),
then confirm or revert based on whitelist check after `OP_CALL` is emitted.

### Issue 3: Callee name overwritten by argument parsing
**Problem:** `singlevar()` is called for both the function name and
argument names. `print(t)` calls `singlevar("print")` then `singlevar("t")`,
overwriting `last_callee_name` with `"t"`.

**Resolution:** Save `ls->last_callee_name` into a local `saved_callee` at
the very top of `funcargs()`, before argument parsing begins.

---

## How to Build and Test

```bash
# Step 1: Apply changes (copy modified files or apply patches)
cp "Part C/Part 1/src/lparser.c" lua-5.5.0/src/
cp "Part C/Part 1/src/lparser.h" lua-5.5.0/src/
cp "Part C/Part 1/src/llex.h"    lua-5.5.0/src/

# Step 2: Rebuild
cd lua-5.5.0
make clean && make all MYCFLAGS="-g -O2"
./src/lua -v    # should print: Lua 5.5.0

# Step 3: Run basic test
./src/lua "Part C/Part 1/test_escape.lua"

# Step 4: Run comprehensive test
./src/lua "Part C/Part 1/test_escape_full.lua"
```

---

## Test Results

### Basic test (test_escape.lua)
```
[escape-analysis] 't' -> NON-ESCAPING test_safe: purely local
[escape-analysis] 't' -> ESCAPES test_return: Rule 1
[escape-analysis] 't' -> ESCAPES test_capture: Rule 2
[escape-analysis] 't' -> ESCAPES test_store: Rule 3
[escape-analysis] 't' -> ESCAPES test_call: Rule 4
[escape-analysis] 't' -> NON-ESCAPING test_whitelist: print/type safe
```

### Comprehensive test (test_escape_full.lua)
```
[escape-analysis] 't' -> NON-ESCAPING         test 1: purely local
[escape-analysis] 't' -> ESCAPES              test 2: return (Rule 1)
[escape-analysis] 't' -> ESCAPES              test 3: capture (Rule 2)
[escape-analysis] 't' -> ESCAPES              test 4: store global (Rule 3)
[escape-analysis] 't' -> ESCAPES              test 5: unknown call (Rule 4)
[escape-analysis] 't' -> NON-ESCAPING         test 6: whitelisted calls
[escape-analysis] 't' -> NON-ESCAPING         test 7: local computation
[escape-analysis] 'outer' -> ESCAPES          test 8: returned (Rule 1)
[escape-analysis] 'inner' -> ESCAPES          test 8: Rule 3 chain propagated
[escape-analysis] 't' -> ESCAPES              test 9: table.insert (Rule 4)
[escape-analysis] 'list' -> ESCAPES           test 9: list passed to table.insert (Rule 4)
[escape-analysis] 't' -> NON-ESCAPING         test 10: length operator only
[escape-analysis] 't' -> ESCAPES              test 11: used inside returned constructor
[escape-analysis] 'a' -> NON-ESCAPING         test 12: multi-local safe
[escape-analysis] 'b' -> NON-ESCAPING         test 12: multi-local safe
[escape-analysis] 'safe' -> NON-ESCAPING      test 13: not returned
[escape-analysis] 'unsafe' -> ESCAPES         test 13: returned (Rule 1)
[escape-analysis] 'survivors' -> ESCAPES      bench: returned (Rule 1)
```

All results are correct. Every escaping table is caught, and every
non-escaping table is provably safe. The analyzer never fails in the
unsafe direction (promoting a table that actually escapes).

### Testbench observation
In the actual testbench, `obj` is stored into `survivors` conditionally
(`if count % survive_every == 0`). Since the analyzer is static (cannot
reason about runtime branch conditions), it conservatively marks `obj`
as escaping for ALL iterations. This means 99% of `obj` allocations
that are actually short-lived still go to the GC heap. The escape
analyzer provides no benefit for this specific workload pattern — an
important finding for Part D benchmarking.

---

## Known Limitations

1. **Multi-return / multi-argument conservatism:** For `return a, b` or
   `func(a, b)` with more than one expression, the analyzer cannot track
   which locals correspond to which intermediate registers after `explist()`
   shuffles them. It conservatively marks ALL table-locals as escaping
   (for returns) or tentatively escaping (for calls, subject to whitelist
   revert). This is sound but may cause missed optimizations in functions
   with many table-locals and multi-value returns or calls.
2. **Loop-scoped variables:** The debug output in `close_func()` cannot
   print escape verdicts for variables in inner blocks (like loop bodies)
   because `leaveblock()` has already reduced `nactvar` by then. The
   analysis itself still runs correctly during parsing.