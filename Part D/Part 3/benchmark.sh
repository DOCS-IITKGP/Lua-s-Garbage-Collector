#!/bin/bash

BASEDIR="/mnt/c/Users/ASUS/OneDrive/Desktop/ACADS/SEMESTER 7/Design Optimisation of Computing Systems/Projects/Assignment 1"
OUTDIR="$BASEDIR/Part D/Part 3"
RESULTS="$OUTDIR/results.txt"
DRIVER="$OUTDIR/d3driver.c"
TESTBENCH="$BASEDIR/testbench.lua"

STOCK_SRC="$BASEDIR/original/lua-5.5.0/src"
MOD_SRC="$BASEDIR/lua5.5-student-src/lua-5.5.0/src"

echo "======================================" > "$RESULTS"
echo "Part D.3: Escape Analyzer Benchmarking" >> "$RESULTS"
echo "Date: $(date)"                           >> "$RESULTS"
echo "======================================" >> "$RESULTS"

# Compile both drivers
echo "Compiling stock driver..."
gcc -g -O2 -I"$STOCK_SRC" -o "$OUTDIR/d3_stock" "$DRIVER" "$STOCK_SRC/liblua.a" -lm -ldl

echo "Compiling modified driver..."
gcc -g -O2 -I"$MOD_SRC" -o "$OUTDIR/d3_modified" "$DRIVER" "$MOD_SRC/liblua.a" -lm -ldl

echo "" >> "$RESULTS"
echo "==========================================" >> "$RESULTS"
echo "MEASUREMENT 1: Compile-Time Overhead"       >> "$RESULTS"
echo "==========================================" >> "$RESULTS"
echo "" >> "$RESULTS"
echo "Comparing instruction count for COMPILING the testbench" >> "$RESULTS"
echo "(not running it — only the load/compile phase matters)" >> "$RESULTS"
echo "" >> "$RESULTS"

# For compile-time cost, we use luac (the compiler) to just compile, not run
echo "--- Stock luac compiling testbench ---" >> "$RESULTS"
valgrind --tool=callgrind --callgrind-out-file="$OUTDIR/compile_stock.out" \
    "$STOCK_SRC/luac" -o /dev/null "$TESTBENCH" 2>&1 >> "$RESULTS"
echo "" >> "$RESULTS"

echo "--- Modified luac compiling testbench ---" >> "$RESULTS"
valgrind --tool=callgrind --callgrind-out-file="$OUTDIR/compile_modified.out" \
    "$MOD_SRC/luac" -o /dev/null "$TESTBENCH" 2>&1 >> "$RESULTS"
echo "" >> "$RESULTS"

echo "--- Stock compile totals ---" >> "$RESULTS"
callgrind_annotate "$OUTDIR/compile_stock.out" | head -20 >> "$RESULTS"
echo "" >> "$RESULTS"

echo "--- Modified compile totals ---" >> "$RESULTS"
callgrind_annotate "$OUTDIR/compile_modified.out" | head -20 >> "$RESULTS"
echo "" >> "$RESULTS"

echo "--- Stock compile: parser functions ---" >> "$RESULTS"
callgrind_annotate "$OUTDIR/compile_stock.out" | grep -i "parser\|constructor\|localstat\|close_func" >> "$RESULTS"
echo "" >> "$RESULTS"

echo "--- Modified compile: parser functions ---" >> "$RESULTS"
callgrind_annotate "$OUTDIR/compile_modified.out" | grep -i "parser\|constructor\|localstat\|close_func" >> "$RESULTS"
echo "" >> "$RESULTS"

echo "==========================================" >> "$RESULTS"
echo "MEASUREMENT 2: Benefit to the Collector"    >> "$RESULTS"
echo "==========================================" >> "$RESULTS"
echo "" >> "$RESULTS"

# Run both with default testbench (m=1000, n=100)
echo "--- m=1000, n=100 (default testbench) ---" >> "$RESULTS"
echo "" >> "$RESULTS"

echo "Stock (incremental GC):" >> "$RESULTS"
valgrind --tool=callgrind --callgrind-out-file="$OUTDIR/run_stock_1000.out" \
    "$OUTDIR/d3_stock" "$TESTBENCH" 2>&1 >> "$RESULTS"
echo "" >> "$RESULTS"

echo "Modified (C.1+C.2 enabled):" >> "$RESULTS"
valgrind --tool=callgrind --callgrind-out-file="$OUTDIR/run_mod_1000.out" \
    "$OUTDIR/d3_modified" "$TESTBENCH" 2>&1 >> "$RESULTS"
echo "" >> "$RESULTS"

# Totals
echo "--- Stock run totals (m=1000) ---" >> "$RESULTS"
callgrind_annotate "$OUTDIR/run_stock_1000.out" | head -20 >> "$RESULTS"
echo "" >> "$RESULTS"

echo "--- Modified run totals (m=1000) ---" >> "$RESULTS"
callgrind_annotate "$OUTDIR/run_mod_1000.out" | head -20 >> "$RESULTS"
echo "" >> "$RESULTS"

# GC function comparison
echo "--- Stock GC functions (m=1000) ---" >> "$RESULTS"
callgrind_annotate "$OUTDIR/run_stock_1000.out" | grep -E "sweeplist|sweepstep|propagatemark|luaC_step|luaC_newobj|luaH_new |freeobj|singlestep|traversearray|reallymark|arena" >> "$RESULTS"
echo "" >> "$RESULTS"

echo "--- Modified GC functions (m=1000) ---" >> "$RESULTS"
callgrind_annotate "$OUTDIR/run_mod_1000.out" | grep -E "sweeplist|sweepstep|propagatemark|luaC_step|luaC_newobj|luaH_new |freeobj|singlestep|traversearray|reallymark|arena" >> "$RESULTS"
echo "" >> "$RESULTS"

echo "Done! Results saved to $RESULTS"