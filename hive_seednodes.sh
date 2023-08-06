#!/bin/bash

# Path below should be linked to Hive's doc/seednodes.txt
FILE_PATH="/etc/munin/seednodes.txt"
STATE_FILE="/var/lib/munin-node/plugin-state/nobody/hive-seednodes.st"

function config {
    echo "graph_title Hive Seed Nodes SLA"
    echo "graph_vlabel Success Ratio"
    echo "graph_category network"
    echo "graph_scale no"
    while IFS= read -r line
    do
        label=$(echo $line | awk '{print $3}')
        echo "${label}.label ${label}"
        echo "${label}.draw LINE2"
        echo "${label}.min 0"
        echo "${label}.max 1"
    done < "$FILE_PATH"
}

function fetch {
    # Load old data
    declare -A old_success
    declare -A old_total
    if [[ -f $STATE_FILE ]]; then
        while IFS= read -r line
        do
            label=$(echo $line | cut -d' ' -f1)
            success=$(echo $line | cut -d' ' -f2)
            total=$(echo $line | cut -d' ' -f3)
            old_success["$label"]=$success
            old_total["$label"]=$total
        done < "$STATE_FILE"
    fi

    > $STATE_FILE  # Empty the state file for new data

    while IFS= read -r input_line
    do
        # Check if the line matches the expected format
        if [[ ! "$input_line" =~ ^[^#]+:[0-9]+\s+#\s+\S+$ ]]; then
            continue  # Skip processing this line
        fi
        
        hostport=$(echo $input_line | awk '{print $1}' | tr ':' '/')
        label=$(echo $input_line | awk '{print $3}')

        total="${old_total[$label]:-0}"
        success="${old_success[$label]:-0}"

        timeout 3 bash -c "cat < /dev/null > /dev/tcp/${hostport}" > /dev/null 2>&1
        if [ $? -eq 0 ]; then
            success=$((success+1))
        fi
        total=$((total+1))

        # Save new data by the label
        echo "$label $success $total" >> $STATE_FILE

        # Output ratio
        ratio=$(echo "$success $total" | awk '{printf "%.2f", $1/$2}')
        echo "${label}.value $ratio"
    done < "$FILE_PATH"
}

case $1 in
    config)
        config
        ;;
    *)  
        fetch
        ;;
esac
