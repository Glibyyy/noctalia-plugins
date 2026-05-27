import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.Commons
import qs.Widgets

ColumnLayout {
  id: root

  property var pluginApi: null

  property int editRefreshInterval:
    pluginApi?.pluginSettings?.refreshInterval || 5000

  property bool editCompactMode:
    pluginApi?.pluginSettings?.compactMode ?? true

  property bool editHideDisconnected:
    pluginApi?.pluginSettings?.hideDisconnected ?? false

  property bool editShowSearchBar:
    pluginApi?.pluginSettings?.showSearchBar ?? false

  property string editTerminalCommand:
    pluginApi?.pluginSettings?.terminalCommand || ""

  property string editSshUsername:
    pluginApi?.pluginSettings?.sshUsername || ""

  property int editPingCount:
    pluginApi?.pluginSettings?.pingCount || 5

  property string editDefaultPeerAction:
    pluginApi?.pluginSettings?.defaultPeerAction || "copy-ip"

  spacing: Style.marginM

  NText {
    text: "Tailscale Multi"
    font.pointSize: Style.fontSizeXL
    font.bold: true
  }

  NText {
    text: "Monitor multiple Tailscale instances. Instances are auto-discovered from running tailscaled sockets."
    color: Color.mSecondary
    Layout.fillWidth: true
    wrapMode: Text.Wrap
  }

  // Refresh
  NDivider { Layout.fillWidth: true; Layout.topMargin: Style.marginM; Layout.bottomMargin: Style.marginM }

  NLabel {
    label: "Refresh Interval"
    description: "How often to poll instance status (" + root.editRefreshInterval + " ms)"
  }

  NSlider {
    Layout.fillWidth: true
    from: 1000
    to: 60000
    stepSize: 1000
    value: root.editRefreshInterval
    onValueChanged: root.editRefreshInterval = value
  }

  // Display
  NDivider { Layout.fillWidth: true; Layout.topMargin: Style.marginM; Layout.bottomMargin: Style.marginM }

  NLabel { label: "Display" }

  NToggle {
    Layout.fillWidth: true
    label: "Compact Mode"
    description: "Icon only in bar (no connected count)"
    checked: root.editCompactMode
    onToggled: checked => root.editCompactMode = checked
  }

  NToggle {
    Layout.fillWidth: true
    label: "Hide Disconnected Peers"
    description: "Only show online peers in the panel"
    checked: root.editHideDisconnected
    onToggled: checked => root.editHideDisconnected = checked
  }

  NToggle {
    Layout.fillWidth: true
    label: "Show Search Bar"
    description: "Search across all peers"
    checked: root.editShowSearchBar
    onToggled: checked => root.editShowSearchBar = checked
  }

  // Terminal
  NDivider { Layout.fillWidth: true; Layout.topMargin: Style.marginM; Layout.bottomMargin: Style.marginM }

  NLabel { label: "Terminal" }

  NTextInput {
    Layout.fillWidth: true
    label: "Terminal Command"
    description: "Used for SSH and ping actions"
    placeholderText: "kitty"
    text: root.editTerminalCommand
    onTextChanged: root.editTerminalCommand = text
  }

  NTextInput {
    Layout.fillWidth: true
    label: "SSH Username"
    description: "Default username for SSH connections"
    placeholderText: "gliby"
    text: root.editSshUsername
    onTextChanged: root.editSshUsername = text
  }

  NLabel {
    label: "Ping Count"
    description: "Number of pings to send (" + root.editPingCount + ")"
  }

  NSlider {
    Layout.fillWidth: true
    from: 1
    to: 20
    stepSize: 1
    value: root.editPingCount
    onValueChanged: root.editPingCount = value
  }

  // Peer action
  NDivider { Layout.fillWidth: true; Layout.topMargin: Style.marginM; Layout.bottomMargin: Style.marginM }

  NComboBox {
    Layout.fillWidth: true
    label: "Default Peer Action"
    description: "Action when clicking a peer"
    model: [
      { key: "copy-ip", name: "Copy IP" },
      { key: "copy-fqdn", name: "Copy FQDN" },
      { key: "ssh", name: "SSH" },
      { key: "ping", name: "Ping" }
    ]
    currentKey: root.editDefaultPeerAction
    onSelected: key => root.editDefaultPeerAction = key
  }

  function saveSettings() {
    if (!pluginApi) return

    pluginApi.pluginSettings.refreshInterval = root.editRefreshInterval
    pluginApi.pluginSettings.compactMode = root.editCompactMode
    pluginApi.pluginSettings.hideDisconnected = root.editHideDisconnected
    pluginApi.pluginSettings.showSearchBar = root.editShowSearchBar
    pluginApi.pluginSettings.terminalCommand = root.editTerminalCommand
    pluginApi.pluginSettings.sshUsername = root.editSshUsername
    pluginApi.pluginSettings.pingCount = root.editPingCount
    pluginApi.pluginSettings.defaultPeerAction = root.editDefaultPeerAction

    pluginApi.saveSettings()
  }
}
