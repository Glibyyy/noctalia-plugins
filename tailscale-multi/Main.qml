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
  property int refreshInterval: _computeRefreshInterval()
  property bool compactMode: _computeCompactMode()

  function _computeRefreshInterval() {
    return pluginApi?.pluginSettings?.refreshInterval ?? 5000
  }
  function _computeCompactMode() {
    return pluginApi?.pluginSettings?.compactMode ?? true
  }

  onSettingsVersionChanged: {
    refreshInterval = _computeRefreshInterval()
    compactMode = _computeCompactMode()
    updateTimer.interval = refreshInterval
  }

  // State
  property var instances: []
  property bool anyConnected: false
  property int connectedCount: 0
  property int totalCount: 0
  property bool isRefreshing: false
  property bool hasAutoStarted: false

  readonly property string _pluginDir: {
    var url = Qt.resolvedUrl(".").toString()
    if (url.startsWith("file://")) url = url.substring(7)
    if (url.endsWith("/")) url = url.substring(0, url.length - 1)
    return url
  }
  readonly property string _queryScript: _pluginDir + "/query.sh"

  function filterIPv4(ips) {
    if (!ips || !ips.length) return []
    return ips.filter(ip => ip.startsWith("100."))
  }

  function resolveHostName(hostName, dnsName) {
    if (hostName && hostName.toLowerCase() !== "localhost") return hostName
    if (!dnsName) return hostName
    var label = dnsName.split(".")[0]
    return label || hostName
  }

  function tailscaleName(dnsName) {
    if (!dnsName) return ""
    return dnsName.split(".")[0] || ""
  }

  function _buildCommand() {
    return ["bash", _queryScript]
  }

  function queryInstances() {
    var cmd = _buildCommand()
    if (cmd.length === 0) return
    root.isRefreshing = true
    queryProcess.command = cmd
    queryProcess.running = true
  }

  // ── Instance actions ─────────────────────────────────────────────

  function connectInstance(socket) {
    actionProcess.command = ["tailscale", "--socket", socket, "up"]
    actionProcess.actionLabel = "Connect"
    actionProcess.running = true
  }

  function disconnectInstance(socket) {
    actionProcess.command = ["tailscale", "--socket", socket, "down"]
    actionProcess.actionLabel = "Disconnect"
    actionProcess.running = true
  }

  function setExitNode(socket, peerIp) {
    actionProcess.command = ["tailscale", "--socket", socket, "set", "--exit-node=" + peerIp]
    actionProcess.actionLabel = "Exit node → " + peerIp
    actionProcess.running = true
  }

  function clearExitNode(socket) {
    actionProcess.command = ["tailscale", "--socket", socket, "set", "--exit-node="]
    actionProcess.actionLabel = "Exit node cleared"
    actionProcess.running = true
  }

  function taildrop(socket, peerIp, filePaths) {
    var cmd = ["tailscale", "--socket", socket, "file", "cp"]
    for (var i = 0; i < filePaths.length; i++) cmd.push(filePaths[i])
    cmd.push(peerIp + ":")
    Quickshell.execDetached(cmd)
  }

  // ── Latency ──────────────────────────────────────────────────────

  property var peerLatencies: ({})
  property int latencyVersion: 0

  function measureLatency(socket, peerIp) {
    latencyProcess.peerIp = peerIp
    latencyProcess.command = ["tailscale", "--socket", socket, "ping", "--c", "1", peerIp]
    latencyProcess.running = true
  }

  // ── Dynamic connection management ────────────────────────────────

  // opts: { name, loginServer, authKey, hostname, advertiseRoutes, acceptDns, acceptRoutes }
  function addConnection(opts) {
    var name = typeof opts === "string" ? opts : opts.name
    addProcess.connectionOpts = typeof opts === "string" ? { name: opts } : opts
    addProcess.command = ["sudo", "tailscale-dynamic-helper", "start", name]
    addProcess.running = true
  }

  function removeConnection(name) {
    removeProcess.command = ["sudo", "tailscale-dynamic-helper", "remove", name]
    removeProcess.running = true
    var list = (pluginApi?.pluginSettings?.managedConnections || []).filter(function(c) {
      return (typeof c === "string" ? c : c.name) !== name
    })
    if (pluginApi?.pluginSettings) {
      pluginApi.pluginSettings.managedConnections = list
      pluginApi.saveSettings()
    }
  }

  function loginInstance(socket, opts) {
    if (!opts) opts = {}
    var name = dynNameFromSocket(socket)
    if (!name) return
    loginProcess.instanceSocket = socket

    // All login goes through the helper (runs as root via sudo)
    var cmd = ["sudo", "tailscale-dynamic-helper", "login", name]
    if (opts.loginServer) cmd.push("--login-server=" + opts.loginServer)
    if (opts.authKey) cmd.push("--authkey=" + opts.authKey)
    if (opts.hostname) cmd.push("--hostname=" + opts.hostname)
    if (opts.advertiseRoutes) cmd.push("--advertise-routes=" + opts.advertiseRoutes)
    cmd.push(opts.acceptDns !== false ? "--accept-dns" : "--accept-dns=false")
    cmd.push(opts.acceptRoutes !== false ? "--accept-routes" : "--accept-routes=false")
    loginProcess.command = cmd
    loginProcess.running = true
  }

  function getConnectionOptsForSocket(socket) {
    var managed = pluginApi?.pluginSettings?.managedConnections || []
    var dynName = dynNameFromSocket(socket)
    for (var i = 0; i < managed.length; i++) {
      var c = managed[i]
      if (typeof c === "string") { if (c === dynName) return { name: c }; continue }
      if (c.name === dynName) return c
    }
    return {}
  }

  function autoStartManagedConnections() {
    var managed = pluginApi?.pluginSettings?.managedConnections || []
    if (managed.length === 0) return
    for (var i = 0; i < managed.length; i++) {
      var c = managed[i]
      var name = typeof c === "string" ? c : c.name
      var expectedSocket = "/run/tailscale-dyn-" + name + "/tailscaled.sock"
      var found = false
      for (var j = 0; j < root.instances.length; j++) {
        if (root.instances[j].socket === expectedSocket) {
          found = true
          break
        }
      }
      if (!found) {
        root.addConnection(c)
        return
      }
    }
  }

  function dynNameFromSocket(socket) {
    var match = (socket || "").match(/\/run\/tailscale-dyn-([^/]+)\//)
    return match ? match[1] : ""
  }

  // ── Server validation ───────────────────────────────────────────

  signal serverCheckResult(string status, int httpCode, string server)

  function checkServer(url) {
    checkProcess.command = ["sudo", "tailscale-dynamic-helper", "check", url]
    checkProcess.running = true
  }

  // ── Processes ────────────────────────────────────────────────────

  Process {
    id: checkProcess
    stdout: StdioCollector {}
    stderr: StdioCollector {}
    onExited: function(exitCode) {
      var output = String(stdout.text || "").trim()
      try {
        var result = JSON.parse(output)
        root.serverCheckResult(result.status || "error", result.http_code || 0, result.server || "")
      } catch (e) {
        root.serverCheckResult("error", 0, "")
      }
    }
  }

  Process {
    id: actionProcess
    property string actionLabel: ""
    stdout: StdioCollector {}
    stderr: StdioCollector {}
    onExited: function(exitCode) {
      if (exitCode !== 0) {
        Logger.e("TailscaleMulti", "Action failed: " + actionLabel + " — " + String(stderr.text || "").trim())
      }
      root.queryInstances()
    }
  }

  Process {
    id: latencyProcess
    property string peerIp: ""
    stdout: StdioCollector {}
    stderr: StdioCollector {}
    onExited: function(exitCode) {
      var output = String(stdout.text || "").trim()
      if (exitCode === 0 && output) {
        var ms = ""
        var match = output.match(/in (\d+(?:\.\d+)?ms)/)
        if (match) ms = match[1]
        var via = ""
        var viaMatch = output.match(/via ([\w()]+)/)
        if (viaMatch) via = viaMatch[1]
        if (ms) {
          var copy = Object.assign({}, root.peerLatencies)
          copy[latencyProcess.peerIp] = ms + (via ? " " + via : "")
          root.peerLatencies = copy
          root.latencyVersion++
        }
      }
    }
  }

  Process {
    id: addProcess
    property var connectionOpts: ({})
    stdout: StdioCollector {}
    stderr: StdioCollector {}
    onExited: function(exitCode) {
      var opts = addProcess.connectionOpts
      var name = opts.name || ""
      if (exitCode === 0 && name) {
        var list = (pluginApi?.pluginSettings?.managedConnections || []).slice()
        var exists = list.some(function(c) {
          return (typeof c === "string" ? c : c.name) === name
        })
        if (!exists) {
          list.push(opts)
          if (pluginApi?.pluginSettings) {
            pluginApi.pluginSettings.managedConnections = list
            pluginApi.saveSettings()
          }
        }
        var sock = "/run/tailscale-dyn-" + name + "/tailscaled.sock"
        root.loginInstance(sock, opts)
      } else {
        Logger.e("TailscaleMulti", "Failed to start connection: " + name)
      }
      root.queryInstances()
    }
  }

  Process {
    id: removeProcess
    stdout: StdioCollector {}
    stderr: StdioCollector {}
    onExited: function(exitCode) {
      root.queryInstances()
    }
  }

  Process {
    id: loginProcess
    property string instanceSocket: ""
    stdout: StdioCollector {}
    stderr: StdioCollector {}
    onExited: function(exitCode) {
      var output = String(stdout.text || "").trim()
      try {
        var result = JSON.parse(output)
        if (result.url) {
          Qt.openUrlExternally(result.url)
        }
      } catch (e) {
        // Fallback: try to find URL in raw output
        var all = output + "\n" + String(stderr.text || "").trim()
        var urlMatch = all.match(/https?:\/\/\S+/)
        if (urlMatch) {
          Qt.openUrlExternally(urlMatch[0])
        }
      }
      root.queryInstances()
    }
  }

  // ── Query parsing ────────────────────────────────────────────────

  Process {
    id: queryProcess
    stdout: StdioCollector {}
    stderr: StdioCollector {}

    onExited: function(exitCode, exitStatus) {
      root.isRefreshing = false
      var stdout = String(queryProcess.stdout.text || "").trim()

      if (exitCode !== 0 || !stdout) return

      try {
        var data = JSON.parse(stdout)
        var newInstances = []
        var connected = 0

        for (var i = 0; i < data.length; i++) {
          var entry = data[i]
          var d = entry.data || {}
          var running = d.BackendState === "Running"
          var needsLogin = d.BackendState === "NeedsLogin"

          var ip = ""
          if (running && d.Self && d.Self.TailscaleIPs) {
            var ipv4s = root.filterIPv4(d.Self.TailscaleIPs)
            ip = ipv4s[0] || d.Self.TailscaleIPs[0] || ""
          }

          var peers = []
          if (running && d.Peer) {
            for (var peerId in d.Peer) {
              var peer = d.Peer[peerId]
              var peerIpv4s = root.filterIPv4(peer.TailscaleIPs)
              peers.push({
                "HostName": root.resolveHostName(peer.HostName, peer.DNSName),
                "DNSName": peer.DNSName,
                "TailscaleIPs": peerIpv4s,
                "Online": peer.Online,
                "OS": peer.OS,
                "Tags": peer.Tags || [],
                "ExitNodeOption": peer.ExitNodeOption || false,
                "ExitNode": peer.ExitNode || false,
                "PrimaryRoutes": peer.PrimaryRoutes || [],
                "CurAddr": peer.CurAddr || "",
                "Relay": peer.Relay || "",
                "Direct": (peer.CurAddr || "") !== ""
              })
            }
          }

          var status = running ? "Connected" : (needsLogin ? "Needs Login" : "Disconnected")
          if (running) connected++

          var displayName = entry.name

          newInstances.push({
            "name": displayName,
            "socket": entry.socket || "",
            "running": running,
            "needsLogin": needsLogin,
            "backendState": d.BackendState || "Unknown",
            "ip": ip,
            "status": status,
            "peerCount": peers.length,
            "peers": peers
          })
        }

        root.instances = newInstances
        root.connectedCount = connected
        root.totalCount = newInstances.length
        root.anyConnected = connected > 0

        if (!root.hasAutoStarted) {
          root.hasAutoStarted = true
          root.autoStartManagedConnections()
        }
      } catch (e) {
        Logger.e("TailscaleMulti", "Failed to parse query result: " + e)
      }
    }
  }

  Timer {
    id: updateTimer
    interval: root.refreshInterval
    repeat: true
    running: true
    triggeredOnStart: true
    onTriggered: root.queryInstances()
  }

  Component.onCompleted: {
    queryInstances()
  }

  IpcHandler {
    target: "plugin:tailscale-multi"

    function status() {
      return {
        "instances": root.instances,
        "connectedCount": root.connectedCount,
        "totalCount": root.totalCount
      }
    }

    function refresh() {
      root.queryInstances()
    }
  }
}
