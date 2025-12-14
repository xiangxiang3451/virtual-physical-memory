#!/bin/bash

echo "🔄 Starting Wine real-time memory change monitoring"
echo "📌 Waiting for Windows program to start in Wine..."

while true; do
    PID=$(ps aux | grep -E "wine.*memory_test\.exe" | grep -v grep | head -1 | awk '{print $2}')
    
    if [ -z "$PID" ]; then
        PID=$(ps aux | grep "memory_test" | grep -v grep | grep -v wine_monitor | head -1 | awk '{print $2}')
    fi
    
    if [ -n "$PID" ] && [ "$PID" != "$$" ]; then
        if ps -p $PID > /dev/null 2>&1; then
            CMDLINE=$(ps -p $PID -o cmd= 2>/dev/null)
            if echo "$CMDLINE" | grep -q "wine\|memory_test"; then
                echo "✅ Found process PID: $PID"
                echo "   Command: $CMDLINE"
                break
            fi
        fi
    fi
    sleep 0.5
done

echo ""
echo "Time           Virtual(MB)    Physical(MB)  Δ(VIRT)     Δ(RES)"
echo "-------------------------------------------------------------------"

# Initialize previous values
LAST_VIRT=""
LAST_RES=""
INITIAL_OUTPUT=false

if [ -f "/proc/$PID/status" ]; then
    INITIAL_VIRT=$(grep VmSize /proc/$PID/status 2>/dev/null | awk '{print $2}')
    INITIAL_RES=$(grep VmRSS /proc/$PID/status 2>/dev/null | awk '{print $2}')
    if [ -n "$INITIAL_VIRT" ] && [ "$INITIAL_VIRT" != "0" ]; then
        INITIAL_VIRT_MB=$(echo "scale=1; $INITIAL_VIRT / 1024" | bc)
        INITIAL_RES_MB=$(echo "scale=1; $INITIAL_RES / 1024" | bc)
        echo "📊 Initial process size: VIRT=${INITIAL_VIRT_MB}MB, RES=${INITIAL_RES_MB}MB"
        LAST_VIRT=$INITIAL_VIRT
        LAST_RES=$INITIAL_RES
    fi
fi

COUNTER=0
NO_CHANGE_COUNT=0

# Fast monitoring loop
while kill -0 $PID 2>/dev/null; do
    PS_INFO=$(ps -p $PID -o vsz=,rss= 2>/dev/null)
    
    if [ -n "$PS_INFO" ]; then
        CURRENT_VIRT=$(echo $PS_INFO | awk '{print $1}')  # KB
        CURRENT_RES=$(echo $PS_INFO | awk '{print $2}')   # KB
        
        if [ -n "$CURRENT_VIRT" ] && [ "$CURRENT_VIRT" != "0" ]; then
            # Use bc for precise MB calculation
            VIRT_MB=$(echo "scale=1; $CURRENT_VIRT / 1024" | bc)
            RES_MB=$(echo "scale=1; $CURRENT_RES / 1024" | bc)
            
            if [ -n "$LAST_VIRT" ] && [ "$LAST_VIRT" != "0" ]; then
                VIRT_CHANGE=$((CURRENT_VIRT - LAST_VIRT))
                RES_CHANGE=$((CURRENT_RES - LAST_RES))
            else
                VIRT_CHANGE=0
                RES_CHANGE=0
            fi
            
            SIGNIFICANT_CHANGE=false
            
            if [ ${VIRT_CHANGE#-} -gt 4 ]; then
                SIGNIFICANT_CHANGE=true
            fi
            
            if [ ${RES_CHANGE#-} -gt 16 ]; then
                SIGNIFICANT_CHANGE=true
            fi
            
            COUNTER=$((COUNTER + 1))
            if [ $COUNTER -ge 10 ] || [ "$SIGNIFICANT_CHANGE" = true ]; then
                TIMESTAMP=$(date '+%H:%M:%S.%3N')
                
                VIRT_CHANGE_STR=""
                RES_CHANGE_STR=""
                
                if [ $VIRT_CHANGE -gt 4 ]; then
                    VIRT_CHANGE_MB=$(echo "scale=1; $VIRT_CHANGE / 1024" | bc)
                    VIRT_CHANGE_STR="+${VIRT_CHANGE_MB}MB"
                elif [ $VIRT_CHANGE -lt -4 ]; then
                    VIRT_CHANGE_MB=$(echo "scale=1; -$VIRT_CHANGE / 1024" | bc)
                    VIRT_CHANGE_STR="-${VIRT_CHANGE_MB}MB"
                fi
                
                if [ $RES_CHANGE -gt 16 ]; then
                    RES_CHANGE_MB=$(echo "scale=1; $RES_CHANGE / 1024" | bc)
                    RES_CHANGE_STR="+${RES_CHANGE_MB}MB"
                elif [ $RES_CHANGE -lt -16 ]; then
                    RES_CHANGE_MB=$(echo "scale=1; -$RES_CHANGE / 1024" | bc)
                    RES_CHANGE_STR="-${RES_CHANGE_MB}MB"
                fi
                
                if [ "$SIGNIFICANT_CHANGE" = false ] && [ $COUNTER -ge 10 ]; then
                    NO_CHANGE_COUNT=$((NO_CHANGE_COUNT + 1))
                    if [ $NO_CHANGE_COUNT -le 3 ]; then  
                        printf "%-15s %14s %14s %12s %12s\n" \
                            "$TIMESTAMP" "$VIRT_MB" "$RES_MB" "(stable)" "(stable)"
                    fi
                else
                    NO_CHANGE_COUNT=0
                    printf "%-15s %14s %14s %12s %12s\n" \
                        "$TIMESTAMP" "$VIRT_MB" "$RES_MB" "${VIRT_CHANGE_STR:- }" "${RES_CHANGE_STR:- }"
                fi
                
                COUNTER=0
            fi
            
            # Update previous values
            LAST_VIRT=$CURRENT_VIRT
            LAST_RES=$CURRENT_RES
        fi
    else
        break
    fi
    
    sleep 0.05
done

echo ""
echo "🍷 Program terminated"
if [ -n "$VIRT_MB" ] && [ -n "$RES_MB" ]; then
    echo "📈 Final stats: VIRT=${VIRT_MB}MB, RES=${RES_MB}MB"
fi
echo "💡 Total runtime: $SECONDS seconds"

echo ""
echo "🔍 Final process information:"
ps -p $PID -o pid,ppid,cmd,vsz,rss,etime 2>/dev/null || echo "Process no longer exists"