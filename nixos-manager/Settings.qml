import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Widgets

ColumnLayout {
  id: root

  property var pluginApi: null

  // Local edit state
  property string editFlakeDir:
    pluginApi?.pluginSettings?.flakeDir || "~/nixos-config"

  property int editRefreshInterval:
    pluginApi?.pluginSettings?.refreshInterval || 60000

  property string editTerminalCommand:
    pluginApi?.pluginSettings?.terminalCommand || "kitty"

  property bool editAutoFetch:
    pluginApi?.pluginSettings?.autoFetch ?? true

  property var editRemoteRepos: []

  onPluginApiChanged: loadFromSettings()
  Component.onCompleted: loadFromSettings()

  function loadFromSettings() {
    if (!pluginApi) return
    var s = pluginApi.pluginSettings

    editFlakeDir = s?.flakeDir || "~/nixos-config"
    editRefreshInterval = s?.refreshInterval || 60000
    editTerminalCommand = s?.terminalCommand || "kitty"
    editAutoFetch = s?.autoFetch ?? true

    var r = s?.remoteRepos
    if (r && r.length > 0) {
      editRemoteRepos = JSON.parse(JSON.stringify(r))
    } else {
      editRemoteRepos = []
    }
  }

  function saveSettings() {
    if (!pluginApi) return
    pluginApi.pluginSettings.flakeDir = root.editFlakeDir
    pluginApi.pluginSettings.refreshInterval = root.editRefreshInterval
    pluginApi.pluginSettings.terminalCommand = root.editTerminalCommand
    pluginApi.pluginSettings.autoFetch = root.editAutoFetch
    pluginApi.pluginSettings.remoteRepos = JSON.parse(JSON.stringify(root.editRemoteRepos))
    pluginApi.saveSettings()
  }

  function addRemoteRepo() {
    var r = editRemoteRepos.slice()
    r.push({ name: "", url: "" })
    editRemoteRepos = r
    saveSettings()
  }

  function removeRemoteRepo(idx) {
    var r = editRemoteRepos.slice()
    r.splice(idx, 1)
    editRemoteRepos = r
    saveSettings()
  }

  // Mutate in-place without reassigning the array — prevents Repeater rebuild
  // Debounced to avoid settings version churn stealing focus from panel
  Timer {
    id: remoteSaveTimer
    interval: 500
    onTriggered: root.saveSettings()
  }

  function updateRemoteField(idx, field, value) {
    editRemoteRepos[idx][field] = value
    remoteSaveTimer.restart()
  }

  // Sync remotes script
  readonly property string _pluginDir: {
    var url = Qt.resolvedUrl(".").toString()
    if (url.startsWith("file://")) url = url.substring(7)
    if (url.endsWith("/")) url = url.substring(0, url.length - 1)
    return url
  }

  Process {
    id: syncRemotesProcess
    stdout: StdioCollector {}
    stderr: StdioCollector {}
    onExited: function(exitCode) {
      syncStatus.text = exitCode === 0 ? "Remotes synced" : "Sync failed"
      syncStatusTimer.start()
    }
  }

  Timer {
    id: syncStatusTimer
    interval: 3000
    onTriggered: syncStatus.text = ""
  }

  spacing: Style.marginM

  NText {
    text: "NixOS Manager"
    font.pointSize: Style.fontSizeXL
    font.bold: true
  }

  NText {
    text: "NixOS rebuild, garbage collection, git operations, and repo monitoring"
    color: Color.mSecondary
    Layout.fillWidth: true
    wrapMode: Text.Wrap
  }

  // ── Repository ──────────────────────────────

  NDivider { Layout.fillWidth: true; Layout.topMargin: Style.marginM; Layout.bottomMargin: Style.marginM }

  NLabel { label: "Repository" }

  NTextInput {
    Layout.fillWidth: true
    label: "Flake Directory"
    description: "Local path to the NixOS config repo"
    placeholderText: "~/nixos-config"
    text: root.editFlakeDir
    onTextChanged: { root.editFlakeDir = text; root.saveSettings() }
  }

  // ── Remote Repos ──────────────────────────────

  NDivider { Layout.fillWidth: true; Layout.topMargin: Style.marginM; Layout.bottomMargin: Style.marginM }

  RowLayout {
    Layout.fillWidth: true
    spacing: Style.marginS

    NText {
      text: "Remote Repos"
      font.pointSize: Style.fontSizeL
      font.bold: true
      Layout.fillWidth: true
    }

    Rectangle {
      implicitWidth: addRemoteRow.implicitWidth + Style.marginS * 2
      implicitHeight: addRemoteRow.implicitHeight + 4
      radius: Style.radiusS
      color: Qt.alpha(Color.mPrimary, 0.15)

      RowLayout {
        id: addRemoteRow
        anchors.centerIn: parent
        spacing: 4

        NIcon { icon: "add"; pointSize: Style.fontSizeS; color: Color.mPrimary }
        NText { text: "Add"; pointSize: Style.fontSizeXS; color: Color.mPrimary; font.weight: Style.fontWeightMedium }
      }

      MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: root.addRemoteRepo()
      }
    }
  }

  NText {
    text: "Git remotes to add to the repo. Use to track upstream or forks."
    color: Color.mSecondary
    Layout.fillWidth: true
    wrapMode: Text.Wrap
    pointSize: Style.fontSizeXS
  }

  Repeater {
    model: root.editRemoteRepos

    delegate: ColumnLayout {
      id: remoteDelegate
      Layout.fillWidth: true
      spacing: Style.marginS
      Layout.topMargin: Style.marginS

      readonly property int remoteIdx: index
      readonly property var remoteData: modelData

      RowLayout {
        Layout.fillWidth: true
        spacing: Style.marginS

        NTextInput {
          Layout.preferredWidth: 120
          label: "Name"
          placeholderText: "upstream"
          text: remoteDelegate.remoteData.name || ""
          onTextChanged: root.updateRemoteField(remoteDelegate.remoteIdx, "name", text)
        }

        NTextInput {
          Layout.fillWidth: true
          label: "URL"
          placeholderText: "https://github.com/user/repo"
          text: remoteDelegate.remoteData.url || ""
          onTextChanged: root.updateRemoteField(remoteDelegate.remoteIdx, "url", text)
        }

        Rectangle {
          implicitWidth: 24; implicitHeight: 24
          radius: Style.radiusS
          color: Qt.alpha(Color.mError, 0.15)
          Layout.alignment: Qt.AlignBottom
          Layout.bottomMargin: 4

          NIcon { anchors.centerIn: parent; icon: "delete"; pointSize: Style.fontSizeXS; color: Color.mError }

          MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: root.removeRemoteRepo(remoteDelegate.remoteIdx)
          }
        }
      }
    }
  }

  // Sync remotes button
  RowLayout {
    Layout.fillWidth: true
    spacing: Style.marginS
    visible: root.editRemoteRepos.length > 0

    NButton {
      text: "Sync Remotes"
      icon: "refresh"
      onClicked: {
        var flake = root.editFlakeDir.replace(/^~/, "")
        var remotes = root.editRemoteRepos
        var cmds = []
        for (var i = 0; i < remotes.length; i++) {
          var r = remotes[i]
          if (r.name && r.url) {
            cmds.push("git -C \"$HOME" + flake + "\" remote remove " + r.name + " 2>/dev/null; git -C \"$HOME" + flake + "\" remote add " + r.name + " " + r.url + " 2>/dev/null; git -C \"$HOME" + flake + "\" fetch " + r.name)
          }
        }
        if (cmds.length > 0) {
          syncRemotesProcess.command = ["bash", "-c", cmds.join(" && ")]
          syncRemotesProcess.running = true
        }
      }
    }

    NText {
      id: syncStatus
      pointSize: Style.fontSizeXS
      color: Color.mPrimary
    }
  }

  // ── General ──────────────────────────────

  NDivider { Layout.fillWidth: true; Layout.topMargin: Style.marginM; Layout.bottomMargin: Style.marginM }

  NLabel { label: "General" }

  NLabel {
    label: "Refresh Interval"
    description: "How often to poll repo status (" + root.editRefreshInterval / 1000 + "s)"
  }

  NSlider {
    Layout.fillWidth: true
    from: 10000
    to: 300000
    stepSize: 5000
    value: root.editRefreshInterval
    onValueChanged: { root.editRefreshInterval = value; root.saveSettings() }
  }

  NToggle {
    Layout.fillWidth: true
    label: "Auto Fetch"
    description: "Automatically git fetch on each refresh cycle"
    checked: root.editAutoFetch
    onToggled: checked => { root.editAutoFetch = checked; root.saveSettings() }
  }

  NTextInput {
    Layout.fillWidth: true
    label: "Terminal Command"
    description: "Terminal emulator for rebuild and GC operations"
    placeholderText: "kitty"
    text: root.editTerminalCommand
    onTextChanged: { root.editTerminalCommand = text; root.saveSettings() }
  }
}
