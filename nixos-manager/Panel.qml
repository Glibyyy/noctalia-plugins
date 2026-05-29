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
  readonly property bool showFileList: mainInstance?.showFileList ?? false
  readonly property bool showNormal: !root.showDiff && !root.showFileList

  readonly property bool panelReady: pluginApi !== null && mainInstance !== null

  property real contentPreferredWidth: panelReady ? ((showDiff || showFileList) ? 520 : 400) * Style.uiScaleRatio : 0
  property real contentPreferredHeight: panelReady ? ((showDiff || showFileList) ? 550 : 480) * Style.uiScaleRatio : 0

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

          // ══════════════════════════════════════════
          // SHARED TOP — always visible
          // ══════════════════════════════════════════

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

          // ── Repo status ────────────────────────────
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

            // Local status badge
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
                  if ((root.repoInfo?.dirty ?? false) && mainInstance) {
                    if (root.showFileList || root.showDiff) mainInstance.closeFileList()
                    else mainInstance.openFileList()
                  }
                }
              }
            }

            // Remote status badge
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
                  if ((behind > 0 || ahead > 0) && mainInstance) {
                    if (root.showDiff) mainInstance.closeDiff()
                    else mainInstance.openDiff("remote")
                  }
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

          // ══════════════════════════════════════════
          // FILE LIST VIEW — replaces bottom section
          // ══════════════════════════════════════════

          Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 1
            color: Qt.alpha(Color.mPrimary, 0.3)
            visible: root.showFileList && !root.showDiff
          }

          RowLayout {
            Layout.fillWidth: true
            spacing: Style.marginS
            visible: root.showFileList && !root.showDiff

            NText {
              text: "Changed Files"
              pointSize: Style.fontSizeS
              font.weight: Style.fontWeightBold
              color: Color.mPrimary
              Layout.fillWidth: true
            }

            NText {
              text: "✕ close"
              pointSize: Style.fontSizeXS
              color: closeFileListMouse.containsMouse ? Color.mError : Color.mOnSurfaceVariant

              MouseArea {
                id: closeFileListMouse
                anchors.fill: parent
                anchors.margins: -4
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                  if (mainInstance) mainInstance.closeFileList()
                }
              }
            }
          }

          Flickable {
            Layout.fillWidth: true
            Layout.fillHeight: true
            visible: root.showFileList && !root.showDiff
            clip: true
            contentHeight: fileListColumn.implicitHeight
            boundsBehavior: Flickable.StopAtBounds

            ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

            ColumnLayout {
              id: fileListColumn
              width: parent.width
              spacing: 2

              Repeater {
                model: root.repoInfo?.changedFiles ?? []

                delegate: Rectangle {
                  Layout.fillWidth: true
                  implicitHeight: fileRow.implicitHeight + 8
                  radius: Style.radiusS
                  color: fileMouse.containsMouse ? Qt.alpha(Color.mOnSurface, 0.06) : "transparent"

                  RowLayout {
                    id: fileRow
                    anchors.fill: parent
                    anchors.margins: 4
                    spacing: Style.marginS

                    NText {
                      text: modelData.status
                      pointSize: Style.fontSizeXS
                      font.weight: Style.fontWeightBold
                      font.family: Settings.data.ui.fontFixed
                      color: {
                        var s = modelData.status
                        if (s === "??" || s === "?") return "#F59E0B"
                        if (s === "A") return "#4ADE80"
                        if (s === "D") return "#F87171"
                        return Color.mTertiary
                      }
                      Layout.preferredWidth: 24
                    }

                    NText {
                      text: modelData.file
                      pointSize: Style.fontSizeXS
                      color: Color.mOnSurface
                      font.family: Settings.data.ui.fontFixed
                      elide: Text.ElideMiddle
                      Layout.fillWidth: true
                    }
                  }

                  MouseArea {
                    id: fileMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                      if (mainInstance) mainInstance.openFileDiff(modelData.file)
                    }
                  }
                }
              }
            }
          }

          // ══════════════════════════════════════════
          // DIFF VIEW — replaces bottom section
          // ══════════════════════════════════════════

          Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 1
            color: Qt.alpha(Color.mPrimary, 0.3)
            visible: root.showDiff
          }

          RowLayout {
            Layout.fillWidth: true
            spacing: Style.marginS
            visible: root.showDiff

            NText {
              text: mainInstance?.diffTitle ?? ""
              pointSize: Style.fontSizeS
              font.weight: Style.fontWeightBold
              color: Color.mPrimary
              Layout.fillWidth: true
            }

            NText {
              text: root.showFileList ? "← back" : "✕ close"
              pointSize: Style.fontSizeXS
              color: closeDiffMouse.containsMouse ? Color.mError : Color.mOnSurfaceVariant

              MouseArea {
                id: closeDiffMouse
                anchors.fill: parent
                anchors.margins: -4
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                  if (mainInstance) mainInstance.closeDiff()
                }
              }
            }
          }

          NText {
            visible: (mainInstance?.isDiffLoading ?? false) && root.showDiff
            text: "Loading..."
            pointSize: Style.fontSizeS
            color: Color.mOnSurfaceVariant
          }

          Flickable {
            Layout.fillWidth: true
            Layout.fillHeight: true
            visible: root.showDiff && (mainInstance?.diffOutput ?? "") !== ""
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

            Text {
              id: diffText
              x: 8
              y: 8
              textFormat: Text.RichText
              text: mainInstance?.diffOutput ?? ""
              font.pointSize: Style.fontSizeXS
              color: Color.mOnSurface
              font.family: Settings.data.ui.fontFixed
            }
          }

          // ══════════════════════════════════════════
          // NORMAL BOTTOM — hidden when diff is open
          // ══════════════════════════════════════════

          // Pull/Push buttons
          NButton {
            Layout.fillWidth: true
            visible: root.showNormal && (root.repoInfo?.behind ?? 0) > 0
            text: "Pull " + (root.repoInfo?.behind ?? 0) + " commit(s)"
            icon: "git-pull-request"
            enabled: !root.isRunning
            onClicked: {
              if (mainInstance) mainInstance.runActionSilent("git-pull")
            }
          }

          NButton {
            Layout.fillWidth: true
            visible: root.showNormal && (root.repoInfo?.ahead ?? 0) > 0
            text: "Push " + (root.repoInfo?.ahead ?? 0) + " commit(s)"
            icon: "send"
            enabled: !root.isRunning
            onClicked: {
              if (mainInstance) mainInstance.runActionSilent("git-push")
            }
          }

          Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 1; color: Qt.alpha(Color.mOnSurface, 0.06); visible: root.showNormal }

          // ── Untracked files warning ─────────────────
          Rectangle {
            Layout.fillWidth: true
            implicitHeight: untrackedRow.implicitHeight + Style.marginS * 2
            radius: Style.radiusS
            color: Qt.alpha("#F59E0B", 0.15)
            visible: root.showNormal && (root.repoInfo?.untrackedCount ?? 0) > 0

            RowLayout {
              id: untrackedRow
              anchors.fill: parent
              anchors.margins: Style.marginS
              spacing: Style.marginS

              NIcon {
                icon: "alert-triangle"
                pointSize: Style.fontSizeS
                color: "#F59E0B"
              }

              NText {
                text: (root.repoInfo?.untrackedCount ?? 0) + " untracked — rebuild will fail"
                pointSize: Style.fontSizeXS
                color: "#F59E0B"
                Layout.fillWidth: true
              }

              NButton {
                text: "Stage All"
                icon: "plus"
                enabled: !root.isRunning
                onClicked: {
                  if (mainInstance) mainInstance.runActionSilent("git-add-untracked")
                }
              }
            }
          }

          // ── Rebuild ─────────────────────────────────
          NText {
            visible: root.showNormal
            text: "Rebuild"
            pointSize: Style.fontSizeS
            font.weight: Style.fontWeightBold
            color: Color.mPrimary
          }

          Flow {
            Layout.fillWidth: true
            spacing: Style.marginS
            visible: root.showNormal

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

          Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 1; color: Qt.alpha(Color.mOnSurface, 0.06); visible: root.showNormal }

          // ── Garbage Collection ───────────────────────
          NText {
            visible: root.showNormal
            text: "Garbage Collection"
            pointSize: Style.fontSizeS
            font.weight: Style.fontWeightBold
            color: Color.mPrimary
          }

          Flow {
            Layout.fillWidth: true
            spacing: Style.marginS
            visible: root.showNormal

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

          Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 1; color: Qt.alpha(Color.mOnSurface, 0.06); visible: root.showNormal }

          // ── Git (only when dirty) ─────────────────
          NTextInput {
            id: commitMsgInput
            visible: root.showNormal && (root.repoInfo?.dirty ?? false)
            Layout.fillWidth: true
            placeholderText: "Commit message..."
            text: root.commitMsg
            onTextChanged: root.commitMsg = commitMsgInput.text
          }

          RowLayout {
            visible: root.showNormal && (root.repoInfo?.dirty ?? false)
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
