import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import qs.Commons
import qs.Widgets
import qs.Services.UI

Item {
  id: root

  property var pluginApi: null
  readonly property var geometryPlaceholder: panelContainer
  readonly property bool allowAttach: true

  readonly property var mainInstance: pluginApi?.mainInstance
  readonly property var sysInfo: mainInstance?.systemInfo ?? null
  readonly property var repoInfo: mainInstance?.repoInfo ?? null
  readonly property bool isRunning: mainInstance?.isRunningAction ?? false

  readonly property bool panelReady: pluginApi !== null && mainInstance !== null

  property real contentPreferredWidth: panelReady ? 400 * Style.uiScaleRatio : 0
  property real contentPreferredHeight: panelReady ? 480 * Style.uiScaleRatio : 0

  property string commitMsg: ""

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
      spacing: 0

      NBox {
        Layout.fillWidth: true
        Layout.fillHeight: true

        ColumnLayout {
          anchors.fill: parent
          anchors.margins: Style.marginM
          spacing: Style.marginS
          clip: true

          // ── Header ──────────────────────────────────
          RowLayout {
            Layout.fillWidth: true
            spacing: Style.marginS

            NIcon {
              icon: "snowflake"
              pointSize: Style.fontSizeL
              color: Color.mPrimary
            }

            ColumnLayout {
              Layout.fillWidth: true
              spacing: 0

              NText {
                text: (root.sysInfo?.hostname ?? "?") + " · gen " + (root.sysInfo?.generation ?? "?")
                pointSize: Style.fontSizeM
                font.weight: Style.fontWeightBold
                color: Color.mOnSurface
              }

              NText {
                text: "Built " + (root.sysInfo?.genDate ?? "?") + " · " + (root.sysInfo?.genCount ?? "?") + " gens"
                pointSize: Style.fontSizeXS
                color: Color.mOnSurfaceVariant
                font.family: Settings.data.ui.fontFixed
              }
            }

            NText {
              visible: root.isRunning
              text: "⟳"
              pointSize: Style.fontSizeL
              color: "#F59E0B"
            }
          }

          Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 1; color: Qt.alpha(Color.mOnSurface, 0.1) }

          // ── Repo status (always visible) ────────────
          RowLayout {
            Layout.fillWidth: true
            spacing: Style.marginS

            NIcon {
              icon: "git-branch"
              pointSize: Style.fontSizeS
              color: Color.mOnSurfaceVariant
            }

            NText {
              text: (root.repoInfo?.branch ?? "?") + " @ " + (root.repoInfo?.lastCommit ?? "?")
              pointSize: Style.fontSizeXS
              color: Color.mOnSurfaceVariant
              font.family: Settings.data.ui.fontFixed
            }

            Item { Layout.fillWidth: true }

            // Local status badge — always shows
            Rectangle {
              implicitWidth: localBadge.implicitWidth + Style.marginS * 2
              implicitHeight: localBadge.implicitHeight + 4
              radius: Style.radiusS
              color: Qt.alpha((root.repoInfo?.dirty ?? false) ? Color.mTertiary : Color.mPrimary, 0.15)

              NText {
                id: localBadge
                anchors.centerIn: parent
                text: (root.repoInfo?.dirty ?? false)
                  ? (root.repoInfo?.dirtyCount ?? 0) + " changed"
                  : "clean"
                pointSize: Style.fontSizeXS
                font.weight: Style.fontWeightMedium
                color: (root.repoInfo?.dirty ?? false) ? Color.mTertiary : Color.mPrimary
                font.family: Settings.data.ui.fontFixed
              }
            }

            // Remote status badge — always shows
            Rectangle {
              implicitWidth: remoteBadge.implicitWidth + Style.marginS * 2
              implicitHeight: remoteBadge.implicitHeight + 4
              radius: Style.radiusS
              color: {
                var behind = root.repoInfo?.behind ?? 0
                var ahead = root.repoInfo?.ahead ?? 0
                if (behind > 0) return Qt.alpha("#F59E0B", 0.15)
                if (ahead > 0) return Qt.alpha(Color.mPrimary, 0.15)
                return Qt.alpha(Color.mPrimary, 0.08)
              }

              NText {
                id: remoteBadge
                anchors.centerIn: parent
                text: {
                  var behind = root.repoInfo?.behind ?? 0
                  var ahead = root.repoInfo?.ahead ?? 0
                  if (behind > 0 && ahead > 0) return "\u2191" + ahead + " \u2193" + behind
                  if (behind > 0) return "\u2193" + behind + " behind"
                  if (ahead > 0) return "\u2191" + ahead + " ahead"
                  return "synced"
                }
                pointSize: Style.fontSizeXS
                font.weight: Style.fontWeightMedium
                color: {
                  var behind = root.repoInfo?.behind ?? 0
                  if (behind > 0) return "#F59E0B"
                  return Color.mPrimary
                }
                font.family: Settings.data.ui.fontFixed
              }
            }
          }

          // Last commit message
          NText {
            text: root.repoInfo?.lastMsg ?? ""
            pointSize: Style.fontSizeXS
            color: Color.mOnSurface
            elide: Text.ElideRight
            Layout.fillWidth: true
          }

          // Pull/Push buttons (only when needed)
          NButton {
            Layout.fillWidth: true
            visible: (root.repoInfo?.behind ?? 0) > 0
            text: "Pull " + (root.repoInfo?.behind ?? 0) + " commit(s)"
            icon: "git-pull-request"
            enabled: !root.isRunning
            onClicked: {
              if (mainInstance) mainInstance.runActionSilent("git-pull")
            }
          }

          NButton {
            Layout.fillWidth: true
            visible: (root.repoInfo?.ahead ?? 0) > 0
            text: "Push " + (root.repoInfo?.ahead ?? 0) + " commit(s)"
            icon: "send"
            enabled: !root.isRunning
            onClicked: {
              if (mainInstance) mainInstance.runActionSilent("git-push")
            }
          }

          Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 1; color: Qt.alpha(Color.mOnSurface, 0.06) }

          // ── Rebuild ─────────────────────────────────
          NText {
            text: "Rebuild"
            pointSize: Style.fontSizeS
            font.weight: Style.fontWeightBold
            color: Color.mPrimary
          }

          Flow {
            Layout.fillWidth: true
            spacing: Style.marginS

            Repeater {
              model: [
                { label: "Switch", mode: "switch", icon: "refresh" },
                { label: "Boot", mode: "boot", icon: "power" },
                { label: "Test", mode: "test", icon: "flask" },
                { label: "Build", mode: "build", icon: "hammer" },
                { label: "Dry", mode: "dry", icon: "eye" },
                { label: "Flake Update", mode: "flake", icon: "package" }
              ]

              delegate: NButton {
                text: modelData.label
                icon: modelData.icon
                enabled: !root.isRunning
                onClicked: {
                  if (mainInstance) mainInstance.runAction("rebuild", [modelData.mode])
                }
              }
            }
          }

          Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 1; color: Qt.alpha(Color.mOnSurface, 0.06) }

          // ── Garbage Collection ───────────────────────
          NText {
            text: "Garbage Collection"
            pointSize: Style.fontSizeS
            font.weight: Style.fontWeightBold
            color: Color.mPrimary
          }

          Flow {
            Layout.fillWidth: true
            spacing: Style.marginS

            Repeater {
              model: [
                { label: "Full Nuke", mode: "full", icon: "trash" },
                { label: "Keep 3", mode: "keep3", icon: "history" },
                { label: "Keep 5", mode: "keep5", icon: "history" },
                { label: "Store", mode: "store", icon: "database" },
                { label: "Dry", mode: "dry", icon: "eye" }
              ]

              delegate: NButton {
                text: modelData.label
                icon: modelData.icon
                enabled: !root.isRunning
                onClicked: {
                  if (mainInstance) mainInstance.runAction("gc", [modelData.mode])
                }
              }
            }
          }

          Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 1; color: Qt.alpha(Color.mOnSurface, 0.06) }

          // ── Git ─────────────────────────────────────
          NTextInput {
            id: commitMsgInput
            Layout.fillWidth: true
            placeholderText: "Commit message..."
            text: root.commitMsg
            onTextChanged: root.commitMsg = commitMsgInput.text
          }

          RowLayout {
            Layout.fillWidth: true
            spacing: Style.marginS

            NButton {
              text: "Commit"
              icon: "git-commit"
              enabled: !root.isRunning && root.commitMsg.trim() !== "" && (root.repoInfo?.dirty ?? false)
              onClicked: {
                if (mainInstance) {
                  mainInstance.runActionSilent("git-commit", [root.commitMsg.trim()])
                  root.commitMsg = ""
                  commitMsgInput.text = ""
                }
              }
            }

            NButton {
              text: "Commit & Push"
              icon: "send"
              enabled: !root.isRunning && root.commitMsg.trim() !== "" && (root.repoInfo?.dirty ?? false)
              onClicked: {
                if (mainInstance) {
                  mainInstance.runActionSilent("git-commit", [root.commitMsg.trim()])
                  root.commitMsg = ""
                  commitMsgInput.text = ""
                  pushDelayTimer.start()
                }
              }
            }
          }

          Timer {
            id: pushDelayTimer
            interval: 1000
            repeat: false
            onTriggered: {
              if (mainInstance) mainInstance.runActionSilent("git-push")
            }
          }
        }
      }
    }
  }
}
