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
  readonly property bool showDiff: mainInstance?.showDiff ?? false

  readonly property bool panelReady: pluginApi !== null && mainInstance !== null

  property real contentPreferredWidth: panelReady ? (showDiff ? 520 : 400) * Style.uiScaleRatio : 0
  property real contentPreferredHeight: panelReady ? (showDiff ? 550 : 480) * Style.uiScaleRatio : 0

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

        // ── Diff View ──────────────────────────────
        ColumnLayout {
          anchors.fill: parent
          anchors.margins: Style.marginM
          spacing: Style.marginS
          visible: root.showDiff

          RowLayout {
            Layout.fillWidth: true
            spacing: Style.marginS

            Rectangle {
              implicitWidth: backRow.implicitWidth + Style.marginS * 2
              implicitHeight: backRow.implicitHeight + 6
              radius: Style.radiusS
              color: backMouse.containsMouse ? Qt.alpha(Color.mPrimary, 0.15) : "transparent"

              RowLayout {
                id: backRow
                anchors.centerIn: parent
                spacing: 4

                NIcon {
                  icon: "arrow-left"
                  pointSize: Style.fontSizeS
                  color: Color.mPrimary
                }

                NText {
                  text: "Back"
                  pointSize: Style.fontSizeS
                  font.weight: Style.fontWeightMedium
                  color: Color.mPrimary
                }
              }

              MouseArea {
                id: backMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                  if (mainInstance) mainInstance.closeDiff()
                }
              }
            }

            NText {
              text: mainInstance?.diffTitle ?? ""
              pointSize: Style.fontSizeM
              font.weight: Style.fontWeightBold
              color: Color.mOnSurface
              Layout.fillWidth: true
            }
          }

          Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 1; color: Qt.alpha(Color.mOnSurface, 0.1) }

          NText {
            visible: mainInstance?.isDiffLoading ?? false
            text: "Loading..."
            pointSize: Style.fontSizeS
            color: Color.mOnSurfaceVariant
          }

          Flickable {
            Layout.fillWidth: true
            Layout.fillHeight: true
            visible: (mainInstance?.diffOutput ?? "") !== ""
            clip: true
            contentWidth: diffText.implicitWidth + 16
            contentHeight: diffText.implicitHeight + 16
            interactive: true
            boundsBehavior: Flickable.StopAtBounds
            flickableDirection: Flickable.AutoFlickIfNeeded

            ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

            Rectangle {
              width: Math.max(parent.contentWidth, parent.width)
              height: Math.max(parent.contentHeight, parent.height)
              color: Qt.alpha(Color.mOnSurface, 0.03)
              radius: Style.radiusS
            }

            NText {
              id: diffText
              x: 8
              y: 8
              text: mainInstance?.diffOutput ?? ""
              pointSize: Style.fontSizeXS
              color: Color.mOnSurface
              font.family: Settings.data.ui.fontFixed
            }
          }
        }

        // ── Normal View ────────────────────────────
        ColumnLayout {
          anchors.fill: parent
          anchors.margins: Style.marginM
          spacing: Style.marginS
          clip: true
          visible: !root.showDiff

          // ── Header ──────────────────────────────────
          RowLayout {
            Layout.fillWidth: true
            spacing: Style.marginS

            NixOSIcon {
              pointSize: Style.fontSizeL
              applyUiScale: false
              iconColor: Color.mPrimary
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

            NIcon {
              icon: "refresh"
              pointSize: Style.fontSizeS
              color: refreshMouse.containsMouse ? Color.mPrimary : Color.mOnSurfaceVariant

              MouseArea {
                id: refreshMouse
                anchors.fill: parent
                anchors.margins: -4
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                  if (mainInstance) mainInstance.queryStatus()
                }
              }
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

            // Local status badge — clickable for diff
            Rectangle {
              implicitWidth: localBadge.implicitWidth + Style.marginS * 2
              implicitHeight: localBadge.implicitHeight + 4
              radius: Style.radiusS
              color: Qt.alpha((root.repoInfo?.dirty ?? false) ? Color.mTertiary : Color.mPrimary,
                localBadgeMouse.containsMouse ? 0.25 : 0.15)

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

              MouseArea {
                id: localBadgeMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: (root.repoInfo?.dirty ?? false) ? Qt.PointingHandCursor : Qt.ArrowCursor
                onClicked: {
                  if ((root.repoInfo?.dirty ?? false) && mainInstance) mainInstance.openDiff("local")
                }
              }
            }

            // Remote status badge — clickable for diff
            Rectangle {
              implicitWidth: remoteBadge.implicitWidth + Style.marginS * 2
              implicitHeight: remoteBadge.implicitHeight + 4
              radius: Style.radiusS
              color: {
                var behind = root.repoInfo?.behind ?? 0
                var ahead = root.repoInfo?.ahead ?? 0
                var base = behind > 0 ? "#F59E0B" : Color.mPrimary
                var alpha = (behind > 0 || ahead > 0) ? (remoteBadgeMouse.containsMouse ? 0.25 : 0.15) : 0.08
                return Qt.alpha(base, alpha)
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

              MouseArea {
                id: remoteBadgeMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: ((root.repoInfo?.behind ?? 0) > 0 || (root.repoInfo?.ahead ?? 0) > 0) ? Qt.PointingHandCursor : Qt.ArrowCursor
                onClicked: {
                  var behind = root.repoInfo?.behind ?? 0
                  var ahead = root.repoInfo?.ahead ?? 0
                  if ((behind > 0 || ahead > 0) && mainInstance) mainInstance.openDiff("remote")
                }
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

          // ── Git (only when dirty) ─────────────────
          NTextInput {
            id: commitMsgInput
            visible: root.repoInfo?.dirty ?? false
            Layout.fillWidth: true
            placeholderText: "Commit message..."
            text: root.commitMsg
            onTextChanged: root.commitMsg = commitMsgInput.text
          }

          RowLayout {
            visible: root.repoInfo?.dirty ?? false
            Layout.fillWidth: true
            spacing: Style.marginS

            NButton {
              text: "Commit"
              icon: "git-commit"
              enabled: !root.isRunning && root.commitMsg.trim() !== ""
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
              enabled: !root.isRunning && root.commitMsg.trim() !== ""
              onClicked: {
                if (mainInstance) {
                  mainInstance.pendingPush = true
                  mainInstance.runActionSilent("git-commit", [root.commitMsg.trim()])
                  root.commitMsg = ""
                  commitMsgInput.text = ""
                }
              }
            }
          }
        }
      }
    }
  }
}
