#!/bin/bash

# Path to the PID file
PID_FILE="/tmp/audio_server.pid"

# Function to check if the audio_server is running
is_running() {
    if [ -f "$PID_FILE" ]; then
        PID=$(cat "$PID_FILE")
        if ps -p $PID > /dev/null; then
            return 0  # audio_server is running
        else
            return 1  # audio_server is not running
        fi
    else
        return 1  # PID file doesn't exist, indicating the server is not running
    fi
}

# Start the audio_server
start() {
    if is_running; then
        echo "audio_server is already running (PID: $(cat $PID_FILE))."
    else
        echo "Starting audio_server..."
        /src/audio_streaming/audio_server -port $AUDIO_STREAM_PORT &> /dev/null & echo $! > "$PID_FILE"
        echo "audio_server started on (PID: $(cat "$PID_FILE"))."
    fi
}

# Stop the audio_server
stop() {
    if is_running; then
        PID=$(cat "$PID_FILE")
        echo "Stopping audio_server (PID: $PID)..."
        kill $PID

        # If the process can't be killed, force kill it
        if [ $? -ne 0 ]; then
            echo "Failed to kill audio_server process PID $PID, trying with kill -9."
            kill -9 $PID
        else
            echo "audio_server process PID $PID has been terminated."
        fi

        rm -f "$PID_FILE"
    else
        echo "audio_server is not running."
    fi
}

# Restart the audio_server
restart() {
    echo "Restarting audio_server..."
    stop
    sleep 1
    start
}

# Check the status of the audio_server
status() {
    if is_running; then
        echo "audio_server is running (PID: $(cat $PID_FILE))."
    else
        echo "audio_server is not running."
    fi
}

# Main program: based on the argument passed, execute the corresponding command
case "$1" in
    start)
        start
        ;;
    stop)
        stop
        ;;
    restart)
        restart
        ;;
    status)
        status
        ;;
    *)
        echo "Usage: $0 {start|stop|restart|status}"
        exit 1
        ;;
esac