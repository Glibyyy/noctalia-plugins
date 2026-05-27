import QtQuick
import Quickshell
import qs.Commons
import Quickshell.Io

Item {
  id: root

  property var pluginApi: null

  onPluginApiChanged: {
    if (pluginApi) settingsVersion++
  }

  property var settingsWatcher: pluginApi?.pluginSettings
  onSettingsWatcherChanged: {
    if (settingsWatcher) settingsVersion++
  }

  property int settingsVersion: 0

  // Settings
  property string flakeDir: pluginApi?.pluginSettings?.flakeDir ?? "~/nixos-config"
  property int refreshInterval: pluginApi?.pluginSettings?.refreshInterval ?? 60000
  property string terminalCommand: pluginApi?.pluginSettings?.terminalCommand ?? "kitty"

  onSettingsVersionChanged: {
    flakeDir = pluginApi?.pluginSettings?.flakeDir ?? "~/nixos-config"
    refreshInterval = pluginApi?.pluginSettings?.refreshInterval ?? 60000
    terminalCommand = pluginApi?.pluginSettings?.terminalCommand ?? "kitty"
    updateTimer.interval = refreshInterval
    queryStatus()
  }

  // State
  property var systemInfo: null
  property var repoInfo: null
  property bool isRefreshing: false
  property bool isRunningAction: false
  property string lastActionOutput: ""

  readonly property string _pluginDir: {
    var url = Qt.resolvedUrl(".").toString()
    if (url.startsWith("file://")) url = url.substring(7)
    if (url.endsWith("/")) url = url.substring(0, url.length - 1)
    return url
  }
  readonly property string _queryScript: _pluginDir + "/query.sh"
  readonly property string _actionScript: _pluginDir + "/action.sh"

  // Derived state for bar widget
  readonly property string genNumber: systemInfo ? systemInfo.generation : "?"
  readonly property bool repoDirty: repoInfo ? repoInfo.dirty : false
  readonly property int repoBehind: repoInfo ? repoInfo.behind : 0
  readonly property string barStatus: {
    if (repoBehind > 0) return "behind"
    if (repoDirty) return "dirty"
    return "clean"
  }

  function queryStatus() {
    root.isRefreshing = true
    queryProcess.command = ["bash", _queryScript, flakeDir]
    queryProcess.running = true
  }

  function runAction(action, args) {
    if (root.isRunningAction) return
    root.isRunningAction = true
    root.lastActionOutput = ""
    var cmd = [terminalCommand, "-e", "bash", _actionScript, action]
    if (args) {
      for (var i = 0; i < args.length; i++) cmd.push(args[i])
    }
    // Set NIXOS_MANAGER_FLAKE_DIR for the action script
    Quickshell.execDetached(["sh", "-c", "NIXOS_MANAGER_FLAKE_DIR='" + flakeDir + "' " + cmd.join(" ")])
    // Refresh after a delay to pick up changes
    actionRefreshTimer.start()
  }

  function runActionSilent(action, args) {
    if (root.isRunningAction) return
    root.isRunningAction = true
    root.lastActionOutput = ""
    var cmd = ["bash", _actionScript, action]
    if (args) {
      for (var i = 0; i < args.length; i++) cmd.push(args[i])
    }
    silentActionProcess.command = cmd
    silentActionProcess.running = true
  }

  Process {
    id: queryProcess
    stdout: StdioCollector {}
    stderr: StdioCollector {}

    onExited: function(exitCode) {
      root.isRefreshing = false
      var output = String(queryProcess.stdout.text || "").trim()
      if (!output) return

      try {
        var data = JSON.parse(output)
        root.systemInfo = data.system || null
        root.repoInfo = data.repo || null
      } catch (e) {
        Logger.e("NixOSManager", "Parse error: " + e)
      }
    }
  }

  Process {
    id: silentActionProcess
    stdout: StdioCollector {}
    stderr: StdioCollector {}

    onExited: function(exitCode) {
      root.isRunningAction = false
      root.lastActionOutput = String(silentActionProcess.stdout.text || "").trim()
      root.queryStatus()
    }
  }

  Timer {
    id: actionRefreshTimer
    interval: 5000
    repeat: false
    onTriggered: {
      root.isRunningAction = false
      root.queryStatus()
    }
  }

  Timer {
    id: updateTimer
    interval: root.refreshInterval
    repeat: true
    running: true
    triggeredOnStart: true
    onTriggered: root.queryStatus()
  }

  Component.onCompleted: {
    queryStatus()
  }

  IpcHandler {
    target: "plugin:nixos-manager"

    function status() {
      return {
        "system": root.systemInfo,
        "repo": root.repoInfo
      }
    }

    function refresh() {
      root.queryStatus()
    }
  }
}
