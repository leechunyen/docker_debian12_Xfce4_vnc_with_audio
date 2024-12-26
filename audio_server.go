package main

import (
    "log"
    "net/http"
    "os/exec"
    "io"
    "flag"
    "fmt"
    "github.com/gorilla/websocket"
)

var (
    port = flag.Int("port", 10001, "Port to listen on")
)

var upgrader = websocket.Upgrader{
    ReadBufferSize:  1024,
    WriteBufferSize: 1024,
    CheckOrigin: func(r *http.Request) bool {
        return true // For development, allow all origins. In production, restrict this.
    },
}

func audioHandler(w http.ResponseWriter, r *http.Request) {
    conn, err := upgrader.Upgrade(w, r, nil)
    if err != nil {
        log.Println("WebSocket upgrade error:", err)
        return
    }
    defer conn.Close()

    // Run FFmpeg to capture audio and encode it in MP2 format
    cmd := exec.Command("ffmpeg", "-f", "alsa", "-i", "pulse", "-f", "mpegts", "-codec:a", "mp2", "-ar", "44100", "-ac", "2", "-b:a", "128k", "-")
    stdout, err := cmd.StdoutPipe()
    if err != nil {
        log.Fatal("Stdout pipe failed:", err)
    }
    if err := cmd.Start(); err != nil {
        log.Fatal("FFmpeg start failed:", err)
    }
    defer cmd.Wait()

    // Copy FFmpeg's output directly to WebSocket
    buffer := make([]byte, 1024)
    for {
        n, err := stdout.Read(buffer)
        if err != nil {
            if err != io.EOF {
                log.Println("Error reading from FFmpeg:", err)
            }
            return
        }
        if err := conn.WriteMessage(websocket.BinaryMessage, buffer[:n]); err != nil {
            log.Println("Error writing to WebSocket:", err)
            return
        }
    }
}

func main() {
    flag.Parse()

    http.HandleFunc("/audio", audioHandler)
    listenAddr := fmt.Sprintf(":%d", *port)
    log.Printf("WebSocket server listening on %s", listenAddr)
    log.Fatal(http.ListenAndServe(listenAddr, nil))
}