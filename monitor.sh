#!/bin/bash

echo "🔄 Starting real-time memory change monitoring"
echo "📌 Waiting for memory_test program to start..."

# Wait for program to start
while true; do
    PID=$(pgrep memory_test)
    if [ -n "$PID" ]; then
        echo "✅ Found process PID: $PID"
        break
    fi
    sleep 0.5
done

echo ""
echo "Time           Virtual(MB)    Physical(MB)  Δ(VIRT)     Δ(RES)"
echo "-------------------------------------------------------------------"

# Initialize previous values
LAST_VIRT=""
LAST_RES=""

# Fast monitoring loop (0.1 second interval)
while kill -0 $PID 2>/dev/null; do
    # Read current memory values
    if [ -f "/proc/$PID/status" ]; then
        CURRENT_VIRT=$(grep VmSize /proc/$PID/status 2>/dev/null | awk '{print $2}')
        CURRENT_RES=$(grep VmRSS /proc/$PID/status 2>/dev/null | awk '{print $2}')
        
        if [ -n "$CURRENT_VIRT" ] && [ "$CURRENT_VIRT" != "0" ]; then
            # Use bc for precise MB calculation (1 decimal place)
            VIRT_MB=$(echo "scale=1; $CURRENT_VIRT / 1024" | bc)
            RES_MB=$(echo "scale=1; $CURRENT_RES / 1024" | bc)
            
            # Calculate changes if previous record exists
            if [ -n "$LAST_VIRT" ]; then
                VIRT_CHANGE=$((CURRENT_VIRT - LAST_VIRT))
                RES_CHANGE=$((CURRENT_RES - LAST_RES))
                
                # Output only if there are changes (>4KB threshold)
                if [ $VIRT_CHANGE -ne 0 ] || [ $RES_CHANGE -ne 0 ]; then
                    TIMESTAMP=$(date '+%H:%M:%S.%3N')
                    
                    # Format change amounts (keep as integer format)
                    VIRT_CHANGE_STR=""
                    RES_CHANGE_STR=""
                    
                    if [ $VIRT_CHANGE -gt 0 ]; then
                        VIRT_CHANGE_STR="+$((VIRT_CHANGE/1024))MB"
                    elif [ $VIRT_CHANGE -lt 0 ]; then
                        VIRT_CHANGE_STR="-$(((-VIRT_CHANGE)/1024))MB"
                    fi
                    
                    if [ $RES_CHANGE -gt 0 ]; then
                        RES_CHANGE_STR="+$((RES_CHANGE/1024))MB"
                    elif [ $RES_CHANGE -lt 0 ]; then
                        RES_CHANGE_STR="-$(((-RES_CHANGE)/1024))MB"
                    fi
                    
                    printf "%-15s %14s %14s %12s %12s\n" \
                        "$TIMESTAMP" "$VIRT_MB" "$RES_MB" "$VIRT_CHANGE_STR" "$RES_CHANGE_STR"
                fi
            else
                # First output
                TIMESTAMP=$(date '+%H:%M:%S.%3N')
                printf "%-15s %14s %14s %12s %12s\n" \
                    "$TIMESTAMP" "$VIRT_MB" "$RES_MB" "Initial" "Initial"
            fi
            
            # Update previous values
            LAST_VIRT=$CURRENT_VIRT
            LAST_RES=$CURRENT_RES
        fi
    fi
    
    # Very short interval for quick change detection
    sleep 0.05  # 
done

echo "Program terminated"