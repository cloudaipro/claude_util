#!/bin/bash

echo "Testing macOS audio alerts..."

# Test 1 beep
echo "Testing 1 beep (50-60% threshold):"
osascript -e "beep" 2>/dev/null || afplay /System/Library/Sounds/Tink.aiff 2>/dev/null || printf '\a'
sleep 1

# Test 2 beeps
echo "Testing 2 beeps (60-70% threshold):"
for i in 1 2; do
    osascript -e "beep" 2>/dev/null || afplay /System/Library/Sounds/Tink.aiff 2>/dev/null || printf '\a'
    [ "$i" -lt 2 ] && sleep 0.3
done
sleep 1

# Test 3 beeps
echo "Testing 3 beeps (70-80% threshold):"
for i in 1 2 3; do
    osascript -e "beep" 2>/dev/null || afplay /System/Library/Sounds/Tink.aiff 2>/dev/null || printf '\a'
    [ "$i" -lt 3 ] && sleep 0.3
done

echo "Audio alert test complete!"