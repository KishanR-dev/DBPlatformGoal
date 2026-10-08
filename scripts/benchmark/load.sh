#!/usr/bin/env bash
# Local development benchmark for ServicePulse Performance Engineering Validation

set -euo pipefail

TARGET_URL=${1:-"http://127.0.0.1:8080"}
DURATION=${2:-"60s"}
RATE=${3:-"50"}

echo "Starting Local Development Benchmark"
echo "Target: $TARGET_URL"
echo "Duration: $DURATION"
echo "Rate: $RATE rps"
echo "-------------------------------------"

if ! command -v vegeta &> /dev/null; then
    echo "This script requires 'vegeta' (https://github.com/tsenart/vegeta)."
    echo "Falling back to apache bench (ab)... if available"
    if ! command -v ab &> /dev/null; then
        echo "Neither vegeta nor ab found. Falling back to simple bash loop."

        # Simple bash parallel load generation
        # NOTE: Not precise measuring, just load generation for dashboard observation
        END_TIME=$(( $(date +%s) + ${DURATION%s} ))

        echo "Running pure bash synthetic load..."
        while [ $(date +%s) -lt $END_TIME ]; do
            for i in $(seq 1 $RATE); do
                curl -s "$TARGET_URL/health" > /dev/null &
            done
            wait
            sleep 1
        done
        echo "Done bash load."
        exit 0
    else
        echo "Running Apache Bench: ab -n $((${DURATION%s} * RATE)) -c 10 $TARGET_URL/health"
        ab -n $((${DURATION%s} * RATE)) -c 10 "$TARGET_URL/health"
        exit 0
    fi
fi

# Run with vegeta if available
echo "GET $TARGET_URL/health" | vegeta attack -duration="$DURATION" -rate="$RATE" | vegeta report
