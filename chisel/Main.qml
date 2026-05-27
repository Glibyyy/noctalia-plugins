import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons

Item {
  id: root

  property var pluginApi: null
  property var cfg: pluginApi?.pluginSettings || ({})
  property var defaults: pluginApi?.manifest?.metadata?.defaultSettings || ({})

  // State exposed to BarWidget
  // "disabled" | "waiting" | "connected"
  property string state: "disabled"
  property string connectionInfo: ""

  // Poll every 5 seconds
  Timer {
    interval: 5000
    running: true
    repeat: true
    triggeredOnStart: true
    onTriggered: checker.running = true
  }

  Process {
    id: checker
    command: ["sh", "-c", `
      if ! pgrep -x chisel > /dev/null 2>&1; then
        echo "STATE:disabled"
      elif ss -tnp 2>/dev/null | grep ':8080 ' | grep -q ESTAB; then
        # Client has an established tunnel on the chisel port
        CLIENT=$(ss -tnp 2>/dev/null | grep ':8080 ' | grep ESTAB | awk '{print $5}' | head -1 | grep -oP '[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+' | tail -1)
        echo "STATE:connected"
        echo "INFO:client $CLIENT"
      else
        echo "STATE:waiting"
      fi
    `]

    stdout: SplitParser {
      onRead: function(line) {
        var trimmed = line.trim()
        if (trimmed.startsWith("STATE:")) {
          root.state = trimmed.substring(6)
        } else if (trimmed.startsWith("INFO:")) {
          root.connectionInfo = trimmed.substring(5)
        }
      }
    }

    onExited: function(exitCode) {
      if (root.state === "") {
        root.state = "disabled"
      }
    }
  }

  IpcHandler {
    target: "plugin:chisel"

    function toggle() {
      if (root.state !== "disabled") {
        stopper.running = true
      } else {
        starter.running = true
      }
    }

    function status() {
      return { "state": root.state, "info": root.connectionInfo }
    }

    function refresh() {
      checker.running = true
    }
  }

  Process {
    id: starter
    command: ["sh", "-c", "nohup chisel server --port 8080 --reverse --socks5 > /tmp/chisel-server.log 2>&1 &"]
    onExited: function(exitCode) {
      checker.running = true
    }
  }

  Process {
    id: stopper
    command: ["pkill", "-x", "chisel"]
    onExited: function(exitCode) {
      root.state = "disabled"
      root.connectionInfo = ""
      checker.running = true
    }
  }
}
