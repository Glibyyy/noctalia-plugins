import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Widgets
import qs.Services.UI

Item {
  id: root

  property var pluginApi: null
  readonly property var geometryPlaceholder: panelContainer
  readonly property bool allowAttach: true

  readonly property var mainInstance: pluginApi?.mainInstance

  function copyToClipboard(text) {
    var escaped = text.replace(/'/g, "'\\''")
    Quickshell.execDetached(["sh", "-c", "printf '%s' '" + escaped + "' | wl-copy"])
  }

  // ── Selection state ────────────────────────────────────────────────
  property var selectedPeer: null
  property var selectedPeerDelegate: null
  property var selectedPeerInstance: null
  property var selectedInstance: null
  property var sendTargetPeer: null
  property var sendTargetInstance: null
  property string searchQuery: ""

  // ── Collapsed state (persisted) ────────────────────────────────────
  property var collapsedInstances: pluginApi?.pluginSettings?.collapsedInstances ?? ({})
  property int collapseVersion: 0

  function toggleCollapsed(name) {
    var copy = Object.assign({}, collapsedInstances)
    copy[name] = !copy[name]
    collapsedInstances = copy
    collapseVersion++
    if (pluginApi?.pluginSettings) {
      pluginApi.pluginSettings.collapsedInstances = copy
      pluginApi.saveSettings()
    }
    contentPreferredHeight = _calcHeight()
  }

  // ── Instance order (persisted, drag-to-reorder) ───────────────────
  property int _orderVersion: 0
  property int dragSourceIndex: -1
  property int dragTargetIndex: -1
  property bool dragActive: false
  property real dragStartY: 0
  property real dragOffsetY: 0
  property real draggedItemHeight: 0
  readonly property int dragThreshold: 8

  function commitReorder(fromIndex, toIndex) {
    if (fromIndex === toIndex || fromIndex < 0 || toIndex < 0) return
    var current = processedInstances.map(function(inst) { return inst.name })
    if (fromIndex >= current.length || toIndex >= current.length) return
    var item = current.splice(fromIndex, 1)[0]
    current.splice(toIndex, 0, item)
    if (pluginApi?.pluginSettings) {
      pluginApi.pluginSettings.instanceOrder = current
      pluginApi.saveSettings()
    }
    _orderVersion++
    contentPreferredHeight = _calcHeight()
  }

  // ── Helpers ────────────────────────────────────────────────────────
  function filterIPv4(ips) {
    return mainInstance?.filterIPv4(ips) || []
  }

  function normalizeFqdn(fqdn) {
    if (!fqdn) return ""
    return fqdn.endsWith(".") ? fqdn.slice(0, -1) : fqdn
  }

  function peerMatchesSearch(peer, query) {
    var trimmedQuery = (query || "").trim().toLowerCase()
    if (trimmedQuery === "") return true
    var ipv4s = filterIPv4(peer?.TailscaleIPs || []).join(" ")
    var fqdn = normalizeFqdn(peer?.DNSName)
    var tsName = mainInstance ? mainInstance.tailscaleName(peer?.DNSName) : ""
    var searchableText = [
      peer?.HostName || "", fqdn, tsName, ipv4s, peer?.OS || "",
      peer?.Relay || "", peer?.PrimaryRoutes?.join(" ") || ""
    ].join(" ").toLowerCase()
    var tokens = trimmedQuery.split(/\s+/)
    for (var i = 0; i < tokens.length; i++) {
      if (searchableText.indexOf(tokens[i]) === -1) return false
    }
    return true
  }

  function getOSIcon(os) {
    if (!os) return "circle-check"
    switch (os.toLowerCase()) {
      case "linux": return "brand-debian"
      case "macos": return "brand-apple"
      case "ios": return "device-mobile"
      case "android": return "device-mobile"
      case "windows": return "brand-windows"
      default: return "circle-check"
    }
  }

  // ── Settings ───────────────────────────────────────────────────────
  readonly property bool hideDisconnected:
    pluginApi?.pluginSettings?.hideDisconnected ?? false
  readonly property bool showSearchBar:
    pluginApi?.pluginSettings?.showSearchBar ?? false
  readonly property string terminalCommand:
    pluginApi?.pluginSettings?.terminalCommand || ""
  readonly property string sshUsername:
    pluginApi?.pluginSettings?.sshUsername || ""
  readonly property int pingCount:
    pluginApi?.pluginSettings?.pingCount || 5
  readonly property string defaultPeerAction:
    pluginApi?.pluginSettings?.defaultPeerAction || "copy-ip"
  readonly property bool isTerminalConfigured: terminalCommand.trim() !== ""

  // ── Pre-process instances ──────────────────────────────────────────
  readonly property var processedInstances: {
    var instances = mainInstance?.instances || []
    var result = []
    for (var i = 0; i < instances.length; i++) {
      var inst = instances[i]
      var peers = (inst.peers || []).slice()

      if (hideDisconnected) {
        peers = peers.filter(function(p) { return p.Online === true })
      }

      peers.sort(function(a, b) {
        if (a.Online && !b.Online) return -1
        if (!a.Online && b.Online) return 1
        var na = (a.HostName || "").toLowerCase()
        var nb = (b.HostName || "").toLowerCase()
        return na.localeCompare(nb)
      })

      if (showSearchBar && searchQuery.trim() !== "") {
        peers = peers.filter(function(p) { return peerMatchesSearch(p, searchQuery) })
      }

      result.push({
        name: inst.name,
        socket: inst.socket,
        running: inst.running,
        needsLogin: inst.needsLogin,
        ip: inst.ip,
        status: inst.status,
        peerCount: inst.peerCount,
        sortedPeers: peers
      })
    }

    // Sort by saved order
    void(root._orderVersion)
    var order = pluginApi?.pluginSettings?.instanceOrder || []
    if (order.length > 0) {
      result.sort(function(a, b) {
        var ia = order.indexOf(a.name)
        var ib = order.indexOf(b.name)
        if (ia === -1) ia = 9999
        if (ib === -1) ib = 9999
        return ia - ib
      })
    }

    return result
  }

  // ── Peer actions ───────────────────────────────────────────────────
  function openPeerContextMenu(peer, inst, delegate, mouseX, mouseY) {
    selectedPeer = peer
    selectedPeerInstance = inst
    selectedPeerDelegate = delegate
    var menuItems = [
      { label: "Copy IP", action: "copy-ip", icon: "clipboard" },
      {
        label: "Copy FQDN", action: "copy-fqdn", icon: "world",
        enabled: normalizeFqdn(peer?.DNSName) !== ""
      },
      {
        label: "SSH", action: "ssh", icon: "terminal",
        enabled: (peer?.Online || false) && isTerminalConfigured
      },
      {
        label: "Ping", action: "ping", icon: "activity",
        enabled: isTerminalConfigured
      },
      {
        label: "Measure Latency", action: "measure-latency", icon: "clock",
        enabled: peer?.Online || false
      }
    ]
    if (peer?.ExitNodeOption) {
      if (peer?.ExitNode) {
        menuItems.push({ label: "Clear Exit Node", action: "clear-exit-node", icon: "globe-off" })
      } else {
        menuItems.push({ label: "Use as Exit Node", action: "set-exit-node", icon: "globe", enabled: peer?.Online || false })
      }
    }
    menuItems.push({
      label: "Send File...", action: "send-file", icon: "file-upload",
      enabled: peer?.Online || false
    })
    peerContextMenu.model = menuItems
    peerContextMenu.openAtItem(delegate, mouseX, mouseY)
  }

  function copySelectedPeerIp() {
    if (!selectedPeer) return
    var ips = filterIPv4(selectedPeer.TailscaleIPs)
    if (ips.length > 0) {
      copyToClipboard(ips[0])
      ToastService.showNotice("IP Copied", ips[0], "clipboard")
    }
  }

  function copySelectedPeerFqdn() {
    if (!selectedPeer) return
    var fqdn = normalizeFqdn(selectedPeer.DNSName)
    if (fqdn) {
      copyToClipboard(fqdn)
      ToastService.showNotice("FQDN Copied", fqdn, "clipboard")
    }
  }

  function sshToSelectedPeer() {
    if (!isTerminalConfigured || !selectedPeer) return
    var ips = filterIPv4(selectedPeer.TailscaleIPs)
    if (ips.length > 0) {
      var target = sshUsername.trim() !== "" ? sshUsername.trim() + "@" + ips[0] : ips[0]
      Quickshell.execDetached([terminalCommand, "-e", "ssh", target])
    }
  }

  function pingSelectedPeer() {
    if (!isTerminalConfigured || !selectedPeer) return
    var ips = filterIPv4(selectedPeer.TailscaleIPs)
    if (ips.length > 0) {
      Quickshell.execDetached([terminalCommand, "-e", "ping", "-c", pingCount.toString(), ips[0]])
    }
  }

  function measureLatencyForPeer() {
    if (!selectedPeer || !selectedPeerInstance || !mainInstance) return
    var ips = filterIPv4(selectedPeer.TailscaleIPs)
    if (ips.length > 0) {
      mainInstance.measureLatency(selectedPeerInstance.socket, ips[0])
      ToastService.showNotice("Measuring", "Pinging " + (selectedPeer.HostName || ips[0]) + "...", "clock")
    }
  }

  function toggleExitNode() {
    if (!selectedPeer || !selectedPeerInstance || !mainInstance) return
    if (selectedPeer.ExitNode) {
      mainInstance.clearExitNode(selectedPeerInstance.socket)
      ToastService.showNotice("Exit Node", "Cleared", "globe-off")
    } else {
      var ips = filterIPv4(selectedPeer.TailscaleIPs)
      if (ips.length > 0) {
        mainInstance.setExitNode(selectedPeerInstance.socket, ips[0])
        ToastService.showNotice("Exit Node", "Set → " + (selectedPeer.HostName || ips[0]), "globe")
      }
    }
  }

  function executePeerAction(action, peer, inst) {
    selectedPeer = peer
    selectedPeerInstance = inst
    switch (action) {
      case "copy-ip": copySelectedPeerIp(); break
      case "copy-fqdn": copySelectedPeerFqdn(); break
      case "ssh": sshToSelectedPeer(); break
      case "ping": pingSelectedPeer(); break
    }
  }

  NContextMenu {
    id: peerContextMenu
    model: []
    onTriggered: function(action) {
      switch (action) {
        case "copy-ip": root.copySelectedPeerIp(); break
        case "copy-fqdn": root.copySelectedPeerFqdn(); break
        case "ssh": root.sshToSelectedPeer(); break
        case "ping": root.pingSelectedPeer(); break
        case "measure-latency": root.measureLatencyForPeer(); break
        case "set-exit-node": root.toggleExitNode(); break
        case "clear-exit-node": root.toggleExitNode(); break
        case "send-file":
          root.sendTargetPeer = root.selectedPeer
          root.sendTargetInstance = root.selectedPeerInstance
          sendFilePicker.openFilePicker()
          break
      }
    }
  }

  // ── Taildrop ───────────────────────────────────────────────────────
  NFilePicker {
    id: sendFilePicker
    title: "Taildrop — select files"
    selectionMode: "files"
    initialPath: Quickshell.env("HOME") ?? ""
    onAccepted: function(paths) {
      if (!mainInstance || !root.sendTargetPeer || !root.sendTargetInstance || paths.length === 0) return
      var ips = root.filterIPv4(root.sendTargetPeer.TailscaleIPs)
      if (ips.length > 0) {
        mainInstance.taildrop(root.sendTargetInstance.socket, ips[0], paths)
        ToastService.showNotice("Taildrop", "Sending " + paths.length + " file(s) to " + (root.sendTargetPeer.HostName || ips[0]), "send")
      }
    }
  }

  // ── Instance context menu ──────────────────────────────────────────
  function isDynamicInstance(inst) {
    return (inst.socket || "").indexOf("tailscale-dyn-") !== -1
  }

  function openInstanceContextMenu(inst, anchor, mouseX, mouseY) {
    selectedInstance = inst
    var items = []
    if (inst.running) {
      items.push({ label: "Disconnect", action: "disconnect", icon: "plug-off" })
    } else {
      items.push({ label: "Connect", action: "connect", icon: "plug" })
    }
    if (inst.needsLogin) {
      items.push({ label: "Login", action: "login", icon: "login" })
    }
    items.push({ label: "Copy IP", action: "copy-instance-ip", icon: "clipboard", enabled: inst.ip !== "" })
    if (isDynamicInstance(inst)) {
      items.push({ label: "Remove Connection", action: "remove", icon: "trash" })
    }
    instanceContextMenu.model = items
    instanceContextMenu.openAtItem(anchor, mouseX, mouseY)
  }

  NContextMenu {
    id: instanceContextMenu
    model: []
    onTriggered: function(action) {
      if (!root.selectedInstance || !mainInstance) return
      switch (action) {
        case "connect":
          mainInstance.connectInstance(root.selectedInstance.socket)
          ToastService.showNotice("Tailscale", "Connecting " + root.selectedInstance.name + "...", "plug")
          break
        case "disconnect":
          mainInstance.disconnectInstance(root.selectedInstance.socket)
          ToastService.showNotice("Tailscale", "Disconnecting " + root.selectedInstance.name + "...", "plug-off")
          break
        case "copy-instance-ip":
          if (root.selectedInstance.ip) {
            root.copyToClipboard(root.selectedInstance.ip)
            ToastService.showNotice("IP Copied", root.selectedInstance.ip, "clipboard")
          }
          break
        case "login":
          var loginOpts = mainInstance.getConnectionOptsForSocket(root.selectedInstance.socket)
          mainInstance.loginInstance(root.selectedInstance.socket, loginOpts)
          ToastService.showNotice("Tailscale", "Opening login for " + root.selectedInstance.name + "...", "login")
          break
        case "remove":
          var dynName = mainInstance.dynNameFromSocket(root.selectedInstance.socket)
          if (dynName) {
            mainInstance.removeConnection(dynName)
            ToastService.showNotice("Tailscale", "Removing " + root.selectedInstance.name, "trash")
          }
          break
      }
    }
  }

  // ── Layout sizing ──────────────────────────────────────────────────
  readonly property bool panelReady: pluginApi !== null && mainInstance !== null && mainInstance !== undefined

  property real contentPreferredWidth: panelReady ? 400 * Style.uiScaleRatio : 0
  property real contentPreferredHeight: root.collapseVersion !== -999 ? _calcHeight() : 0

  function _calcHeight() {
    if (!panelReady) return 0
    var instances = processedInstances
    var peerHeight = 48
    var totalHeaders = 0
    var totalPeers = 0
    for (var i = 0; i < instances.length; i++) {
      var isCollapsed = collapsedInstances[instances[i].name] === true
      totalHeaders += isCollapsed ? 50 : 70
      if (!isCollapsed) {
        totalPeers += instances[i].sortedPeers.length
      }
    }
    var addRowHeight = addForm.visible ? 340 : 45
    var total = totalHeaders + totalPeers * peerHeight + addRowHeight + 20
    return Math.min(700, Math.max(150, total)) * Style.uiScaleRatio
  }

  anchors.fill: parent

  Rectangle {
    id: panelContainer
    anchors.fill: parent
    color: "transparent"
    visible: panelReady

    ColumnLayout {
      anchors {
        fill: parent
        margins: Style.marginM
      }
      spacing: Style.marginS

      NBox {
        Layout.fillWidth: true
        Layout.fillHeight: true

        ColumnLayout {
          anchors.fill: parent
          anchors.margins: Style.marginM
          spacing: Style.marginM
          clip: true

          // Panel title
          RowLayout {
            Layout.fillWidth: true
            spacing: Style.marginS

            NIcon {
              icon: "network"
              pointSize: Style.fontSizeL
              color: Color.mPrimary
            }

            NText {
              text: "Tailscale"
              pointSize: Style.fontSizeL
              font.weight: Style.fontWeightBold
              color: Color.mOnSurface
              Layout.fillWidth: true
            }

            NText {
              text: (mainInstance?.connectedCount ?? 0) + "/" + (mainInstance?.totalCount ?? 0) + " connected"
              pointSize: Style.fontSizeS
              color: Color.mOnSurfaceVariant
            }
          }

          // Search bar
          NTextInput {
            id: searchInput
            Layout.fillWidth: true
            visible: root.showSearchBar && (mainInstance?.anyConnected ?? false)
            placeholderText: "Search peers..."
            inputIconName: "search"
            text: root.searchQuery
            onTextChanged: root.searchQuery = searchInput.text
            Keys.onEscapePressed: {
              if (searchInput.text !== "") searchInput.text = ""
            }
          }

          Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 1
            color: Qt.alpha(Color.mOnSurface, 0.1)
          }

          // Scrollable instance list
          Flickable {
            id: mainFlickable
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            contentWidth: width
            contentHeight: instanceColumn.implicitHeight
            interactive: contentHeight > height
            boundsBehavior: Flickable.StopAtBounds

            ColumnLayout {
              id: instanceColumn
              width: mainFlickable.width
              spacing: Style.marginL

              Repeater {
                id: instanceRepeater
                model: root.processedInstances

                delegate: ColumnLayout {
                  id: instanceDelegate
                  Layout.fillWidth: true
                  spacing: Style.marginS
                  z: root.dragActive && root.dragSourceIndex === instanceDelegate.instanceIndex ? 10 : 0

                  readonly property var inst: modelData
                  readonly property int instanceIndex: index
                  readonly property bool collapsed: root.collapseVersion >= 0 && root.collapsedInstances[inst.name] === true

                  // ── Live drag transform ────────────────────────
                  property real dragShiftTarget: {
                    if (!root.dragActive) return 0
                    var si = root.dragSourceIndex
                    var ti = root.dragTargetIndex
                    var idx = instanceDelegate.instanceIndex
                    if (idx === si) return root.dragOffsetY
                    var shiftAmount = root.draggedItemHeight + instanceColumn.spacing
                    if (si < ti && idx > si && idx <= ti) return -shiftAmount
                    if (si > ti && idx >= ti && idx < si) return shiftAmount
                    return 0
                  }

                  property real dragShiftAnimated: 0
                  onDragShiftTargetChanged: dragShiftAnimated = dragShiftTarget

                  Behavior on dragShiftAnimated {
                    enabled: root.dragActive && instanceDelegate.instanceIndex !== root.dragSourceIndex
                    NumberAnimation { duration: 200; easing.type: Easing.OutCubic }
                  }

                  transform: Translate { y: instanceDelegate.dragShiftAnimated }

                  // ── Instance header ──────────────────────────
                  MouseArea {
                    id: headerMouse
                    Layout.fillWidth: true
                    Layout.preferredHeight: headerContent.implicitHeight
                    hoverEnabled: true
                    cursorShape: root.dragActive ? Qt.ClosedHandCursor : Qt.PointingHandCursor
                    acceptedButtons: Qt.LeftButton | Qt.RightButton
                    preventStealing: true

                    property bool didDrag: false

                    onPressed: function(mouse) {
                      if (mouse.button === Qt.LeftButton) {
                        headerMouse.didDrag = false
                        root.dragSourceIndex = instanceDelegate.instanceIndex
                        root.dragStartY = mapToItem(instanceColumn, 0, mouse.y).y
                        root.draggedItemHeight = instanceDelegate.height
                        root.dragOffsetY = 0
                      }
                    }

                    onPositionChanged: function(mouse) {
                      if (root.dragSourceIndex < 0) return
                      var posY = mapToItem(instanceColumn, 0, mouse.y).y
                      var offset = posY - root.dragStartY
                      if (!root.dragActive) {
                        if (Math.abs(offset) > root.dragThreshold) {
                          root.dragActive = true
                          headerMouse.didDrag = true
                        }
                        return
                      }
                      root.dragOffsetY = offset
                      var step = root.draggedItemHeight + instanceColumn.spacing
                      var steps = Math.round(offset / step)
                      root.dragTargetIndex = Math.max(0, Math.min(
                        root.processedInstances.length - 1,
                        root.dragSourceIndex + steps
                      ))
                    }

                    onReleased: function(mouse) {
                      if (root.dragActive) {
                        root.commitReorder(root.dragSourceIndex, root.dragTargetIndex)
                      }
                      var wasDrag = headerMouse.didDrag
                      root.dragActive = false
                      root.dragSourceIndex = -1
                      root.dragTargetIndex = -1
                      root.dragOffsetY = 0
                      headerMouse.didDrag = false

                      if (!wasDrag && mouse.button === Qt.LeftButton) {
                        root.toggleCollapsed(instanceDelegate.inst.name)
                      }
                    }

                    onClicked: function(mouse) {
                      if (mouse.button === Qt.RightButton) {
                        root.openInstanceContextMenu(instanceDelegate.inst, headerMouse, mouse.x, mouse.y)
                      }
                    }

                    ColumnLayout {
                      id: headerContent
                      anchors.left: parent.left
                      anchors.right: parent.right
                      spacing: 2

                      RowLayout {
                        Layout.fillWidth: true
                        spacing: Style.marginS

                        NIcon {
                          icon: instanceDelegate.collapsed ? "chevron-right" : "chevron-down"
                          pointSize: Style.fontSizeS
                          color: headerMouse.containsMouse ? Color.mPrimary : Color.mOnSurfaceVariant
                        }

                        Rectangle {
                          width: 8; height: 8; radius: 4
                          color: instanceDelegate.inst.running ? Color.mPrimary
                            : (instanceDelegate.inst.needsLogin ? "#F59E0B" : Color.mOnSurfaceVariant)
                        }

                        NText {
                          text: instanceDelegate.inst.name
                          pointSize: Style.fontSizeM
                          font.weight: Style.fontWeightBold
                          color: headerMouse.containsMouse ? Color.mPrimary : Color.mOnSurface
                          Layout.fillWidth: true
                        }

                        NText {
                          visible: instanceDelegate.collapsed && instanceDelegate.inst.running
                          text: instanceDelegate.inst.peerCount + " peers"
                          pointSize: Style.fontSizeXS
                          color: Color.mOnSurfaceVariant
                        }
                      }

                      // IP + status line
                      NText {
                        visible: !instanceDelegate.collapsed
                        Layout.leftMargin: 16
                        text: {
                          var parts = []
                          if (instanceDelegate.inst.ip) parts.push(instanceDelegate.inst.ip)
                          if (instanceDelegate.inst.running) {
                            parts.push(instanceDelegate.inst.peerCount + " peers")
                          } else {
                            parts.push(instanceDelegate.inst.status)
                          }
                          return parts.join(" \u2022 ")
                        }
                        pointSize: Style.fontSizeXS
                        color: Color.mOnSurfaceVariant
                        font.family: Settings.data.ui.fontFixed
                      }
                    }
                  }

                  // Separator
                  Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 1
                    color: Qt.alpha(Color.mOnSurface, 0.06)
                    visible: !instanceDelegate.collapsed && instanceDelegate.inst.sortedPeers.length > 0
                  }

                  // ── Peer list ────────────────────────────────
                  Repeater {
                    model: instanceDelegate.inst.sortedPeers

                    delegate: ItemDelegate {
                      id: peerDelegate
                      visible: !instanceDelegate.collapsed
                      Layout.fillWidth: true
                      implicitHeight: visible ? contentItem.implicitHeight + topPadding + bottomPadding : 0
                      topPadding: Style.marginS
                      bottomPadding: Style.marginS
                      leftPadding: Style.marginL
                      rightPadding: Style.marginL

                      readonly property var peerData: modelData
                      readonly property string peerIp: root.filterIPv4(peerData.TailscaleIPs)[0] || ""
                      readonly property string peerHostname: peerData.HostName || root.normalizeFqdn(peerData.DNSName) || "Unknown"
                      readonly property string peerTsName: mainInstance ? mainInstance.tailscaleName(peerData.DNSName) : ""
                      readonly property bool peerOnline: peerData.Online || false

                      background: Rectangle {
                        anchors.fill: parent
                        color: peerDelegate.hovered
                          ? Qt.alpha(Color.mPrimary, 0.1)
                          : peerDropArea.containsDrag ? Qt.alpha(Color.mTertiary, 0.15)
                          : "transparent"
                        radius: Style.radiusM
                        border.width: peerDelegate.hovered || peerDropArea.containsDrag ? 1 : 0
                        border.color: peerDropArea.containsDrag ? Color.mTertiary : Qt.alpha(Color.mPrimary, 0.3)
                      }

                      // Taildrop drop area
                      DropArea {
                        id: peerDropArea
                        anchors.fill: parent
                        keys: ["text/uri-list"]
                        onDropped: function(drop) {
                          if (!mainInstance || !peerDelegate.peerOnline) return
                          var urls = drop.urls
                          var files = []
                          for (var i = 0; i < urls.length; i++) {
                            var u = urls[i].toString()
                            if (u.startsWith("file://")) files.push(u.substring(7))
                          }
                          if (files.length > 0) {
                            mainInstance.taildrop(instanceDelegate.inst.socket, peerDelegate.peerIp, files)
                            ToastService.showNotice("Taildrop", "Sending " + files.length + " file(s) to " + peerDelegate.peerHostname, "send")
                          }
                          drop.accept()
                        }
                      }

                      contentItem: RowLayout {
                        spacing: Style.marginM

                        NIcon {
                          icon: root.getOSIcon(peerDelegate.peerData.OS)
                          pointSize: Style.fontSizeM
                          color: peerDelegate.peerOnline ? Color.mPrimary : Color.mOnSurfaceVariant
                        }

                        ColumnLayout {
                          spacing: 0
                          Layout.fillWidth: true

                          NText {
                            text: peerDelegate.peerHostname
                            color: peerDelegate.peerOnline ? Color.mOnSurface : Qt.alpha(Color.mOnSurface, 0.4)
                            font.weight: Style.fontWeightMedium
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                          }

                          NText {
                            text: peerDelegate.peerTsName
                            pointSize: Style.fontSizeXS
                            color: Color.mOnSurfaceVariant
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                            visible: peerDelegate.peerTsName !== "" && peerDelegate.peerTsName !== peerDelegate.peerHostname
                          }

                          NText {
                            text: peerDelegate.peerData.PrimaryRoutes?.length > 0
                              ? "\u2192 " + peerDelegate.peerData.PrimaryRoutes.join(", ") : ""
                            pointSize: Style.fontSizeXS
                            color: peerDelegate.peerOnline ? Qt.alpha(Color.mPrimary, 0.7) : Qt.alpha(Color.mOnSurfaceVariant, 0.4)
                            font.family: Settings.data.ui.fontFixed
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                            visible: (peerDelegate.peerData.PrimaryRoutes?.length || 0) > 0
                          }
                        }

                        NIcon {
                          icon: "globe"
                          pointSize: Style.fontSizeS
                          color: peerDelegate.peerData.ExitNode ? Color.mPrimary : Qt.alpha(Color.mOnSurfaceVariant, 0.4)
                          visible: peerDelegate.peerData.ExitNode || peerDelegate.peerData.ExitNodeOption
                          Layout.alignment: Qt.AlignRight

                          MouseArea {
                            anchors.fill: parent
                            anchors.margins: -4
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                              root.selectedPeer = peerDelegate.peerData
                              root.selectedPeerInstance = instanceDelegate.inst
                              root.toggleExitNode()
                            }
                          }
                        }

                        NText {
                          text: peerDelegate.peerIp
                          pointSize: Style.fontSizeS
                          color: peerDelegate.peerOnline ? Color.mOnSurfaceVariant : Qt.alpha(Color.mOnSurfaceVariant, 0.4)
                          font.family: Settings.data.ui.fontFixed
                          visible: peerDelegate.peerIp !== ""
                          Layout.alignment: Qt.AlignRight
                        }
                      }

                      onClicked: {
                        if (peerDelegate.peerIp) {
                          root.executePeerAction(root.defaultPeerAction, peerDelegate.peerData, instanceDelegate.inst)
                        }
                      }

                      TapHandler {
                        acceptedButtons: Qt.RightButton
                        onTapped: root.openPeerContextMenu(peerDelegate.peerData, instanceDelegate.inst, peerDelegate, point.position.x, point.position.y)
                      }
                    }
                  }

                  // Empty state
                  NText {
                    Layout.fillWidth: true
                    Layout.leftMargin: Style.marginL
                    text: "No peers"
                    visible: !instanceDelegate.collapsed && instanceDelegate.inst.running && instanceDelegate.inst.sortedPeers.length === 0
                    pointSize: Style.fontSizeS
                    color: Color.mOnSurfaceVariant
                  }
                }
              }

              // Global empty state
              NText {
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignHCenter
                Layout.topMargin: Style.marginL
                text: "No tailscale instances found"
                visible: root.processedInstances.length === 0
                pointSize: Style.fontSizeM
                color: Color.mOnSurfaceVariant
                horizontalAlignment: Text.AlignHCenter
              }
            }
          }
        }
      }

      // ── Add Connection ──────────────────────────────────────────
      NButton {
        Layout.fillWidth: true
        text: addForm.visible ? "Cancel" : "Add Connection"
        icon: addForm.visible ? "x" : "plus"
        onClicked: {
          addForm.visible = !addForm.visible
          if (!addForm.visible) {
            newConnectionName.text = ""
            newLoginServer.text = ""
          }
          root.contentPreferredHeight = root._calcHeight()
        }
      }

      ColumnLayout {
        id: addForm
        visible: false
        Layout.fillWidth: true
        spacing: Style.marginS

        NTextInput {
          id: newConnectionName
          Layout.fillWidth: true
          placeholderText: "Name (e.g. homelab, work)"
        }

        NTextInput {
          id: newLoginServer
          Layout.fillWidth: true
          placeholderText: "Login server (blank = tailscale.com)"
          onTextChanged: testServerBtn.serverCheckState = ""
        }

        RowLayout {
          Layout.fillWidth: true
          visible: newLoginServer.text.trim() !== ""
          spacing: Style.marginS

          NButton {
            id: testServerBtn
            text: serverCheckState === "" ? "Test Server"
              : serverCheckState === "checking" ? "Checking..."
              : serverCheckState === "ok" ? "Reachable"
              : "Unreachable"
            icon: serverCheckState === "" ? "plug"
              : serverCheckState === "checking" ? "loader"
              : serverCheckState === "ok" ? "circle-check"
              : "circle-x"
            enabled: serverCheckState !== "checking" && newLoginServer.text.trim() !== ""
            Layout.fillWidth: true
            onClicked: {
              serverCheckState = "checking"
              if (mainInstance) mainInstance.checkServer(newLoginServer.text.trim())
            }

            property string serverCheckState: ""

            Connections {
              target: mainInstance
              function onServerCheckResult(status, httpCode, server) {
                testServerBtn.serverCheckState = status === "ok" ? "ok" : "fail"
                if (status === "ok") {
                  ToastService.showNotice("Server OK", server + " (HTTP " + httpCode + ")", "circle-check")
                } else {
                  ToastService.showNotice("Server Unreachable", server + " (HTTP " + httpCode + ")", "circle-x")
                }
              }
            }
          }
        }

        NTextInput {
          id: newAuthKey
          Layout.fillWidth: true
          placeholderText: "Auth key (optional — skips browser)"
        }

        NTextInput {
          id: newHostname
          Layout.fillWidth: true
          placeholderText: "Hostname (optional — defaults to machine)"
        }

        NTextInput {
          id: newAdvertiseRoutes
          Layout.fillWidth: true
          placeholderText: "Advertise routes (e.g. 192.168.1.0/24)"
        }

        NToggle {
          id: newAcceptDns
          Layout.fillWidth: true
          label: "Accept DNS"
          checked: false
          onToggled: checked => newAcceptDns.checked = checked
        }

        NToggle {
          id: newAcceptRoutes
          Layout.fillWidth: true
          label: "Accept Routes"
          checked: true
          onToggled: checked => newAcceptRoutes.checked = checked
        }

        NButton {
          Layout.fillWidth: true
          text: "Create"
          icon: "plus"
          enabled: newConnectionName.text.trim() !== ""
          onClicked: {
            var opts = {
              name: newConnectionName.text.trim(),
              loginServer: newLoginServer.text.trim(),
              authKey: newAuthKey.text.trim(),
              hostname: newHostname.text.trim(),
              advertiseRoutes: newAdvertiseRoutes.text.trim(),
              acceptDns: newAcceptDns.checked,
              acceptRoutes: newAcceptRoutes.checked
            }
            if (opts.name && mainInstance) {
              mainInstance.addConnection(opts)
              ToastService.showNotice("Tailscale", "Starting " + opts.name + "...", "plus")
              newConnectionName.text = ""
              newLoginServer.text = ""
              newAuthKey.text = ""
              newHostname.text = ""
              newAdvertiseRoutes.text = ""
              newAcceptDns.checked = true
              newAcceptRoutes.checked = true
              addForm.visible = false
            }
          }
        }
      }
    }

  }
}
