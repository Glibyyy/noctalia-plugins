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
  property string stopCode: pluginApi?.pluginSettings?.stopCode ?? "21477"
  property var lines: pluginApi?.pluginSettings?.lines ?? ["32", "33", "54"]
  property int refreshInterval: pluginApi?.pluginSettings?.refreshInterval ?? 30000
  property bool compactMode: pluginApi?.pluginSettings?.compactMode ?? true

  onSettingsVersionChanged: {
    stopCode = pluginApi?.pluginSettings?.stopCode ?? "21477"
    lines = pluginApi?.pluginSettings?.lines ?? ["32", "33", "54"]
    refreshInterval = pluginApi?.pluginSettings?.refreshInterval ?? 30000
    compactMode = pluginApi?.pluginSettings?.compactMode ?? true
    updateTimer.interval = refreshInterval
    queryArrivals()
  }

  // State
  property var arrivals: []
  property string stopName: ""
  property bool isRefreshing: false
  property int nextEta: -1

  readonly property string _pluginDir: {
    var url = Qt.resolvedUrl(".").toString()
    if (url.startsWith("file://")) url = url.substring(7)
    if (url.endsWith("/")) url = url.substring(0, url.length - 1)
    return url
  }
  readonly property string _queryScript: _pluginDir + "/query.sh"

  function queryArrivals() {
    root.isRefreshing = true
    var lineFilter = lines.join(",")
    queryProcess.command = ["bash", _queryScript, stopCode, lineFilter]
    queryProcess.running = true
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
        root.arrivals = data.arrivals || []
        root.stopName = data.stopName || ""
        root.nextEta = root.arrivals.length > 0 ? root.arrivals[0].eta : -1
      } catch (e) {
        Logger.e("BusTracker", "Parse error: " + e)
      }
    }
  }

  Timer {
    id: updateTimer
    interval: root.refreshInterval
    repeat: true
    running: true
    triggeredOnStart: true
    onTriggered: root.queryArrivals()
  }

  Component.onCompleted: {
    queryArrivals()
  }

  IpcHandler {
    target: "plugin:bus-tracker"

    function status() {
      return {
        "arrivals": root.arrivals,
        "stopName": root.stopName,
        "nextEta": root.nextEta
      }
    }

    function refresh() {
      root.queryArrivals()
    }
  }
}
