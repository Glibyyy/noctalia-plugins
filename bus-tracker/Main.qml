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
  property var profiles: pluginApi?.pluginSettings?.profiles ?? []
  property int activeProfile: pluginApi?.pluginSettings?.activeProfile ?? -1
  property int refreshInterval: pluginApi?.pluginSettings?.refreshInterval ?? 30000
  property int activeHoursStart: pluginApi?.pluginSettings?.activeHoursStart ?? 9
  property int activeHoursEnd: pluginApi?.pluginSettings?.activeHoursEnd ?? 20
  property int notifyBeforeMinutes: pluginApi?.pluginSettings?.notifyBeforeMinutes ?? 10

  onSettingsVersionChanged: {
    profiles = pluginApi?.pluginSettings?.profiles ?? []
    activeProfile = pluginApi?.pluginSettings?.activeProfile ?? -1
    refreshInterval = pluginApi?.pluginSettings?.refreshInterval ?? 30000
    activeHoursStart = pluginApi?.pluginSettings?.activeHoursStart ?? 9
    activeHoursEnd = pluginApi?.pluginSettings?.activeHoursEnd ?? 20
    notifyBeforeMinutes = pluginApi?.pluginSettings?.notifyBeforeMinutes ?? 10
    updateTimer.interval = refreshInterval
    queryArrivals()
  }

  // Current profile
  readonly property var currentProfile: (activeProfile >= 0 && activeProfile < profiles.length) ? profiles[activeProfile] : null

  // State
  property var stopsData: []
  property var connections: []
  property bool isRefreshing: false
  property int nextEta: -1
  property string nextLine: ""
  property bool hasError: false
  property string lastUpdated: ""

  // Notification state
  property var trackedNotification: null // {line, stopIndex, arrivalIndex, eta, setTime, notifyAt}

  readonly property string _pluginDir: {
    var url = Qt.resolvedUrl(".").toString()
    if (url.startsWith("file://")) url = url.substring(7)
    if (url.endsWith("/")) url = url.substring(0, url.length - 1)
    return url
  }
  readonly property string _queryScript: _pluginDir + "/query.sh"
  readonly property string _searchScript: _pluginDir + "/search.sh"

  function isWithinActiveHours() {
    var now = new Date()
    var hour = now.getHours()
    return hour >= activeHoursStart && hour < activeHoursEnd
  }

  function switchProfile(index) {
    if (index >= 0 && index < profiles.length) {
      activeProfile = index
      if (pluginApi) {
        pluginApi.pluginSettings.activeProfile = index
        pluginApi.saveSettings()
      }
      queryArrivals()
    }
  }

  function queryArrivals() {
    if (!currentProfile || currentProfile.stops.length === 0) return
    if (!isWithinActiveHours()) {
      root.stopsData = []
      root.connections = []
      root.nextEta = -1
      root.nextLine = ""
      return
    }

    root.isRefreshing = true
    var input = JSON.stringify({
      stops: currentProfile.stops,
      walkTime: currentProfile.walkTime || 5
    })
    queryProcess.command = ["bash", _queryScript, input]
    queryProcess.running = true
  }

  Process {
    id: queryProcess
    stdout: StdioCollector {}
    stderr: StdioCollector {}

    onExited: function(exitCode) {
      root.isRefreshing = false
      var output = String(queryProcess.stdout.text || "").trim()
      if (!output) {
        root.hasError = true
        return
      }

      try {
        var data = JSON.parse(output)
        root.stopsData = data.stops || []
        root.connections = data.connections || []
        root.hasError = false

        var now = new Date()
        root.lastUpdated = ("0" + now.getHours()).slice(-2) + ":" + ("0" + now.getMinutes()).slice(-2)

        // Find earliest ETA across first stop
        var earliest = -1
        var earliestLine = ""
        if (root.stopsData.length > 0) {
          var lines = root.stopsData[0].lines || []
          for (var i = 0; i < lines.length; i++) {
            var arrs = lines[i].arrivals || []
            if (arrs.length > 0 && (earliest === -1 || arrs[0].eta < earliest)) {
              earliest = arrs[0].eta
              earliestLine = lines[i].line
            }
          }
        }
        root.nextEta = earliest
        root.nextLine = earliestLine
      } catch (e) {
        root.hasError = true
        Logger.e("BusTracker", "Parse error: " + e)
      }
    }
  }

  // Notification tracking
  function setNotification(line, stopIndex, arrivalIndex, eta) {
    var now = Date.now()
    var delayMs = Math.max(0, (eta - notifyBeforeMinutes) * 60 * 1000)
    root.trackedNotification = {
      line: line,
      stopIndex: stopIndex,
      arrivalIndex: arrivalIndex,
      eta: eta,
      setTime: now,
      notifyAt: now + delayMs
    }
    notifyTimer.interval = Math.max(1000, delayMs)
    notifyTimer.restart()
  }

  function clearNotification() {
    root.trackedNotification = null
    notifyTimer.stop()
  }

  Timer {
    id: notifyTimer
    repeat: false
    onTriggered: {
      if (root.trackedNotification) {
        notifyProcess.command = [
          "notify-send", "-u", "critical", "-i", "bus",
          "Bus " + root.trackedNotification.line + " arriving soon",
          "Time to go! Bus " + root.trackedNotification.line + " arrives in ~" + root.notifyBeforeMinutes + " minutes."
        ]
        notifyProcess.running = true
        root.trackedNotification = null
      }
    }
  }

  Process {
    id: notifyProcess
    onExited: function() {}
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
        "stopsData": root.stopsData,
        "connections": root.connections,
        "nextEta": root.nextEta,
        "nextLine": root.nextLine,
        "activeProfile": root.activeProfile,
        "profiles": root.profiles
      }
    }

    function refresh() {
      root.queryArrivals()
    }
  }
}
