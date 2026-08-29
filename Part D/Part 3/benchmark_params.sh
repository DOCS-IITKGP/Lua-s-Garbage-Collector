#!/bin/bash

BASEDIR="/mnt/c/Users/ASUS/OneDrive/Desktop/ACADS/SEMESTER 7/Design Optimisation of Computing Systems/Projects/Assignment 1"
OUTDIR="$BASEDIR/Part D/Part 3"
RESULTS="$OUTDIR/results_params.txt"
STOCK="$OUTDIR/d3_stock"
MOD="$OUTDIR/d3_modified"

echo "=============================================" > "$RESULTS"
echo "Part D.3: Multi-Parameter Collector Benefit"   >> "$RESULTS"
echo "Date: $(date)"                                  >> "$RESULTS"
echo "=============================================" >> "$RESULTS"

for m in 100 500 5000; do
    TB="$OUTDIR/testbench_${m}.lua"
    echo "" >> "$RESULTS"
    echo "=============================================" >> "$RESULTS"
    echo "  m=${m}, n=100 (${m}00 total allocations)"   >> "$RESULTS"
    echo "=============================================" >> "$RESULTS"

    echo "" >> "$RESULTS"
    echo "--- Stock (m=${m}) ---" >> "$RESULTS"
    valgrind --tool=callgrind \
        --callgrind-out-file="$OUTDIR/run_stock_${m}.out" \
        "$STOCK" "$TB" 2>&1 >> "$RESULTS"
    echo "" >> "$RESULTS"

    echo "--- Modified (m=${m}) ---" >> "$RESULTS"
    valgrind --tool=callgrind \
        --callgrind-out-file="$OUTDIR/run_mod_${m}.out" \
        "$MOD" "$TB" 2>&1 >> "$RESULTS"
    echo "" >> "$RESULTS"

    echo "--- Stock totals (m=${m}) ---" >> "$RESULTS"
    callgrind_annotate "$OUTDIR/run_stock_${m}.out" | head -20 >> "$RESULTS"
    echo "" >> "$RESULTS"

    echo "--- Modified totals (m=${m}) ---" >> "$RESULTS"
    callgrind_annotate "$OUTDIR/run_mod_${m}.out" | head -20 >> "$RESULTS"
    echo "" >> "$RESULTS"

    echo "--- Stock GC functions (m=${m}) ---" >> "$RESULTS"
    callgrind_annotate "$OUTDIR/run_stock_${m}.out" | grep -E "sweeplist|luaC_newobj|luaH_new |freeobj|singlestep|luaC_step|propagatemark|traversearray|reallymark" | head -15 >> "$RESULTS"
    echo "" >> "$RESULTS"

    echo "--- Modified GC functions (m=${m}) ---" >> "$RESULTS"
    callgrind_annotate "$OUTDIR/run_mod_${m}.out" | grep -E "sweeplist|luaC_newobj|luaH_new |freeobj|singlestep|luaC_step|propagatemark|traversearray|reallymark|arena" | head -15 >> "$RESULTS"
    echo "" >> "$RESULTS"
done

echo "Done! Results saved to $RESULTS"