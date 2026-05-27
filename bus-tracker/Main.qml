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
  property var stop1: pluginApi?.pluginSettings?.stop1 ?? { code: "21477", lines: ["33", "32", "54"] }
  property var stop2: pluginApi?.pluginSettings?.stop2 ?? { code: "21450", lines: ["32", "33", "42", "54", "525", "531", "621"] }
  property int refreshInterval: pluginApi?.pluginSettings?.refreshInterval ?? 30000

  onSettingsVersionChanged: {
    stop1 = pluginApi?.pluginSettings?.stop1 ?? { code: "21477", lines: ["33", "32", "54"] }
    stop2 = pluginApi?.pluginSettings?.stop2 ?? { code: "21450", lines: ["32", "33", "42", "54", "525", "531", "621"] }
    refreshInterval = pluginApi?.pluginSettings?.refreshInterval ?? 30000
    updateTimer.interval = refreshInterval
    queryArrivals()
  }

  // State
  property var stopData1: null
  property var stopData2: null
  property var connections: []
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
    var s1 = stop1.code || ""
    var l1 = (stop1.lines || []).join(",")
    var s2 = stop2.code || ""
    var l2 = (stop2.lines || []).join(",")
    queryProcess.command = ["bash", _queryScript, s1, l1, s2, l2]
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
        root.stopData1 = data.stop1 || null
        root.stopData2 = data.stop2 || null
        root.connections = data.connections || []

        // Find earliest ETA across stop 1
        var earliest = -1
        if (root.stopData1) {
          var lines = root.stopData1.lines || []
          for (var i = 0; i < lines.length; i++) {
            var arrs = lines[i].arrivals || []
            if (arrs.length > 0 && (earliest === -1 || arrs[0].eta < earliest)) {
              earliest = arrs[0].eta
            }
          }
        }
        root.nextEta = earliest
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
        "stop1": root.stopData1,
        "stop2": root.stopData2,
        "connections": root.connections,
        "nextEta": root.nextEta
      }
    }

    function refresh() {
      root.queryArrivals()
    }
  }
}
