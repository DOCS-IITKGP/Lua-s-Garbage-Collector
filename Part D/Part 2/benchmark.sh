#!/bin/bash

SWEEPTEST="./sweeptest"
OUTDIR="../Part D/Part 2"
RESULTS="$OUTDIR/results.txt"

echo "======================================" > "$RESULTS"
echo "Part D.2: Sweep-Step Benchmarking"      >> "$RESULTS"
echo "Date: $(date)"                           >> "$RESULTS"
echo "======================================" >> "$RESULTS"

echo ""                                        >> "$RESULTS"
echo "=== Wall-Clock Times ==="                >> "$RESULTS"
for val in 5 20 50 200; do
    echo "--- GCSWEEPMAX = $val ---"           >> "$RESULTS"
    { time $SWEEPTEST $val ; } 2>&1             >> "$RESULTS"
    echo ""                                    >> "$RESULTS"
done

echo "=== Running Callgrind ==="               >> "$RESULTS"
for val in 5 20 50 200; do
    echo "--- Callgrind: GCSWEEPMAX = $val ---" >> "$RESULTS"
    valgrind --tool=callgrind \
        --callgrind-out-file="$OUTDIR/sweep_${val}.out" \
        $SWEEPTEST $val 2>&1                    >> "$RESULTS"
    echo ""                                    >> "$RESULTS"
done

echo "=== Instruction Count Totals ==="        >> "$RESULTS"
for val in 5 20 50 200; do
    echo "--- GCSWEEPMAX = $val ---"           >> "$RESULTS"
    callgrind_annotate "$OUTDIR/sweep_${val}.out" | head -30 >> "$RESULTS"
    echo ""                                    >> "$RESULTS"
done

echo "=== sweepstep Breakdown ==="             >> "$RESULTS"
for val in 5 20 50 200; do
    echo "--- GCSWEEPMAX = $val ---"           >> "$RESULTS"
    callgrind_annotate "$OUTDIR/sweep_${val}.out" | grep -i "sweep" >> "$RESULTS"
    echo ""                                    >> "$RESULTS"
done

echo "=== Top 15 Functions by Instruction Count ===" >> "$RESULTS"
for val in 5 20 50 200; do
    echo "--- GCSWEEPMAX = $val ---"           >> "$RESULTS"
    callgrind_annotate "$OUTDIR/sweep_${val}.out" | grep -E "^[0-9 ,]+" | head -15 >> "$RESULTS"
    echo ""                                    >> "$RESULTS"
done

echo "Done! Results saved to $RESULTS"