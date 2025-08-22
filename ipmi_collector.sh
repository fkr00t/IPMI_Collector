#!/bin/bash

# IPMI Metrics Collector untuk Prometheus
# Menggunakan ipmitool untuk mengumpulkan data dari BMC servers
# Kompatibel dengan Dashboard Grafana custom

# Configuration
COLLECTOR_PORT=8000
COLLECTION_INTERVAL=30

# Configuration file path
CONFIG_FILE="config/servers.conf"

# Load server configuration from external file
load_server_config() {
    if [[ ! -f "$CONFIG_FILE" ]]; then
        echo "ERROR: Configuration file not found: $CONFIG_FILE"
        echo "Please create the configuration file with your server credentials."
        echo "See config/servers.conf.example for reference."
        exit 1
    fi
    
    # Source the configuration file
    source "$CONFIG_FILE"
    
    # Validate that SERVERS array is defined
    if [[ ${#SERVERS[@]} -eq 0 ]]; then
        echo "ERROR: No servers configured in $CONFIG_FILE"
        exit 1
    fi
    
    echo "Loaded configuration for ${#SERVERS[@]} servers"
}

# Parse sensor data and generate Prometheus metrics
parse_sensor_data() {
    local server_name="$1"
    local sensor_output="$2"
    
    if [[ -z "$sensor_output" ]]; then
        return
    fi
    
    echo "$sensor_output" | while IFS='|' read -r sensor_name value unit status rest; do
        # Clean up whitespace
        sensor_name=$(echo "$sensor_name" | xargs)
        value=$(echo "$value" | xargs)
        unit=$(echo "$unit" | xargs)
        status=$(echo "$status" | xargs)
        
        # Skip if no value or invalid
        if [[ "$value" == "na" || -z "$value" ]]; then
            continue
        fi
        
        # Check if value is numeric
        if ! [[ "$value" =~ ^[0-9]+\.?[0-9]*$ ]]; then
            continue
        fi
        
        # Determine sensor state (0=ok, 1=warning, 2=critical)
        local state=0
        if [[ "$status" =~ [Nn][Cc] ]] || [[ "$status" =~ [Cc]ritical ]]; then
            state=2
        elif [[ "$status" =~ [Nn][Rr] ]] || [[ "$status" =~ [Ww]arning ]]; then
            state=1
        fi
        
        # Generate Prometheus metrics based on unit
        if [[ "$unit" =~ [Dd]egrees ]]; then
            echo "ipmi_temperature_celsius{instance=\"$server_name\",name=\"$sensor_name\"} $value"
        elif [[ "$unit" =~ [Vv]olts ]]; then
            echo "ipmi_voltage_volts{instance=\"$server_name\",name=\"$sensor_name\"} $value"
        elif [[ "$unit" =~ [Rr][Pp][Mm] ]]; then
            echo "ipmi_fan_speed_rpm{instance=\"$server_name\",name=\"$sensor_name\"} $value"
        elif [[ "$unit" =~ [Ww]atts ]]; then
            echo "ipmi_power_watts{instance=\"$server_name\",name=\"$sensor_name\"} $value"
        fi
        
        # Add sensor state
        echo "ipmi_sensor_state{instance=\"$server_name\",name=\"$sensor_name\"} $state"
        
    done
}

# Collect data from a single server
collect_server_data() {
    local server_name="$1"
    
    # Get sensor data
    local sensor_output=$(run_ipmitool "$server_name" "sensor")
    if [[ $? -eq 0 ]]; then
        parse_sensor_data "$server_name" "$sensor_output"
    fi
}

# Generate Prometheus metrics page
generate_metrics_page() {
    local temp_file=$(mktemp)
    
    # Add Prometheus header
    cat > "$temp_file" << EOF
# HELP ipmi_temperature_celsius Temperature in Celsius
# TYPE ipmi_temperature_celsius gauge
# HELP ipmi_voltage_volts Voltage in Volts
# TYPE ipmi_voltage_volts gauge
# HELP ipmi_fan_speed_rpm Fan speed in RPM
# TYPE ipmi_fan_speed_rpm gauge
# HELP ipmi_power_watts Power consumption in Watts
# TYPE ipmi_power_watts gauge
# HELP ipmi_sensor_state Sensor state
# TYPE ipmi_sensor_state gauge
# HELP ipmi_bmc_info BMC information
# TYPE ipmi_bmc_info gauge

EOF
    
    # Collect data from all servers
    for server_name in "${!SERVERS[@]}"; do
        collect_server_data "$server_name" >> "$temp_file"
        
        # Add BMC info for template variable
        echo "ipmi_bmc_info{instance=\"$server_name\"} 1" >> "$temp_file"
    done
    
    # Move to final location
    mv "$temp_file" /tmp/ipmi_metrics.prom
}

# HTTP server function using Python
start_http_server() {
    local port="$1"
    
    # Use Python's built-in HTTP server
    python3 -c "
import http.server
import socketserver
import os

class MetricsHandler(http.server.BaseHTTPRequestHandler):
    def do_GET(self):
        if self.path == '/metrics':
            self.send_response(200)
            self.send_header('Content-type', 'text/plain')
            self.end_headers()
            try:
                with open('/tmp/ipmi_metrics.prom', 'r') as f:
                    self.wfile.write(f.read().encode())
            except FileNotFoundError:
                self.wfile.write(b'# No metrics available yet\n')
        else:
            self.send_response(404)
            self.end_headers()
            self.wfile.write(b'Not found\n')

with socketserver.TCPServer(('', $port), MetricsHandler) as httpd:
    httpd.serve_forever()
" &
}

# Main function
main() {
    echo "Starting IPMI Metrics Collector"
    
    # Create metrics file if it doesn't exist
    touch /tmp/ipmi_metrics.prom
    
    # Start HTTP server in background
    start_http_server "$COLLECTOR_PORT"
    local http_pid=$!
    
    echo "Prometheus metrics server started on port $COLLECTOR_PORT"
    
    # Main collection loop
    while true; do
        generate_metrics_page
        echo "Metrics updated at $(date)"
        sleep "$COLLECTION_INTERVAL"
    done
}

# Handle signals
cleanup() {
    echo "Shutting down IPMI collector"
    # Kill background processes
    pkill -f "python3.*socketserver"
    exit 0
}

trap cleanup SIGTERM SIGINT

# Check if ipmitool is available
if ! command -v ipmitool &> /dev/null; then
    echo "ERROR: ipmitool is not installed. Please install it first."
    exit 1
fi

# Check if python3 is available
if ! command -v python3 &> /dev/null; then
    echo "ERROR: python3 is not installed. Please install it first."
    exit 1
fi

# Load server configuration
load_server_config

# Run main function
main
