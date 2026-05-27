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
  property real contentPreferredHeight: panelReady ? 550 * Style.uiScaleRatio : 0

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

          // Header
          RowLayout {
            Layout.fillWidth: true
            spacing: Style.marginS

            NIcon {
              icon: "snowflake"
              pointSize: Style.fontSizeL
              color: Color.mPrimary
            }

            NText {
              text: "NixOS Manager"
              pointSize: Style.fontSizeL
              font.weight: Style.fontWeightBold
              color: Color.mOnSurface
              Layout.fillWidth: true
            }

            NText {
              visible: root.isRunning
              text: "running..."
              pointSize: Style.fontSizeXS
              color: "#F59E0B"
            }
          }

          Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 1
            color: Qt.alpha(Color.mOnSurface, 0.1)
          }

          Flickable {
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            contentWidth: width
            contentHeight: panelColumn.implicitHeight
            interactive: contentHeight > height
            boundsBehavior: Flickable.StopAtBounds

            ColumnLayout {
              id: panelColumn
              width: parent.width
              spacing: Style.marginM

              // ── System Status ─────────────────────────
              ColumnLayout {
                Layout.fillWidth: true
                spacing: Style.marginS

                NText {
                  text: "System"
                  pointSize: Style.fontSizeS
                  font.weight: Style.fontWeightBold
                  color: Color.mPrimary
                }

                // Gen + host + kernel
                RowLayout {
                  Layout.fillWidth: true
                  spacing: Style.marginM

                  ColumnLayout {
                    spacing: 0
                    NText {
                      text: "Generation"
                      pointSize: Style.fontSizeXS
                      color: Color.mOnSurfaceVariant
                    }
                    NText {
                      text: root.sysInfo?.generation ?? "?"
                      pointSize: Style.fontSizeM
                      font.weight: Style.fontWeightBold
                      color: Color.mOnSurface
                      font.family: Settings.data.ui.fontFixed
                    }
                  }

                  ColumnLayout {
                    spacing: 0
                    NText {
                      text: "Host"
                      pointSize: Style.fontSizeXS
                      color: Color.mOnSurfaceVariant
                    }
                    NText {
                      text: root.sysInfo?.hostname ?? "?"
                      pointSize: Style.fontSizeS
                      color: Color.mOnSurface
                      font.family: Settings.data.ui.fontFixed
                    }
                  }

                  ColumnLayout {
                    spacing: 0
                    NText {
                      text: "Store"
                      pointSize: Style.fontSizeXS
                      color: Color.mOnSurfaceVariant
                    }
                    NText {
                      text: root.sysInfo?.storeSize ?? "?"
                      pointSize: Style.fontSizeS
                      color: Color.mOnSurface
                      font.family: Settings.data.ui.fontFixed
                    }
                  }
                }

                NText {
                  text: "Built: " + (root.sysInfo?.genDate ?? "unknown")
                  pointSize: Style.fontSizeXS
                  color: Color.mOnSurfaceVariant
                  font.family: Settings.data.ui.fontFixed
                }
              }

              Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 1
                color: Qt.alpha(Color.mOnSurface, 0.06)
              }

              // ── Repo Status ───────────────────────────
              ColumnLayout {
                Layout.fillWidth: true
                spacing: Style.marginS

                RowLayout {
                  Layout.fillWidth: true
                  spacing: Style.marginS

                  NText {
                    text: "Repository"
                    pointSize: Style.fontSizeS
                    font.weight: Style.fontWeightBold
                    color: Color.mPrimary
                    Layout.fillWidth: true
                  }

                  // Behind badge
                  Rectangle {
                    visible: (root.repoInfo?.behind ?? 0) > 0
                    implicitWidth: behindText.implicitWidth + Style.marginS * 2
                    implicitHeight: behindText.implicitHeight + 4
                    radius: Style.radiusS
                    color: Qt.alpha("#F59E0B", 0.15)

                    NText {
                      id: behindText
                      anchors.centerIn: parent
                      text: root.repoInfo.behind + " behind"
                      pointSize: Style.fontSizeXS
                      color: "#F59E0B"
                      font.family: Settings.data.ui.fontFixed
                    }
                  }

                  // Ahead badge
                  Rectangle {
                    visible: (root.repoInfo?.ahead ?? 0) > 0
                    implicitWidth: aheadText.implicitWidth + Style.marginS * 2
                    implicitHeight: aheadText.implicitHeight + 4
                    radius: Style.radiusS
                    color: Qt.alpha(Color.mPrimary, 0.15)

                    NText {
                      id: aheadText
                      anchors.centerIn: parent
                      text: root.repoInfo.ahead + " ahead"
                      pointSize: Style.fontSizeXS
                      color: Color.mPrimary
                      font.family: Settings.data.ui.fontFixed
                    }
                  }

                  // Dirty badge
                  Rectangle {
                    visible: root.repoInfo?.dirty ?? false
                    implicitWidth: dirtyText.implicitWidth + Style.marginS * 2
                    implicitHeight: dirtyText.implicitHeight + 4
                    radius: Style.radiusS
                    color: Qt.alpha(Color.mTertiary, 0.15)

                    NText {
                      id: dirtyText
                      anchors.centerIn: parent
                      text: (root.repoInfo?.dirtyCount ?? 0) + " changed"
                      pointSize: Style.fontSizeXS
                      color: Color.mTertiary
                      font.family: Settings.data.ui.fontFixed
                    }
                  }
                }

                NText {
                  text: (root.repoInfo?.branch ?? "") + " @ " + (root.repoInfo?.lastCommit ?? "")
                  pointSize: Style.fontSizeXS
                  color: Color.mOnSurfaceVariant
                  font.family: Settings.data.ui.fontFixed
                }

                NText {
                  text: root.repoInfo?.lastMsg ?? ""
                  pointSize: Style.fontSizeXS
                  color: Color.mOnSurface
                  elide: Text.ElideRight
                  Layout.fillWidth: true
                }

                // Pull button
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
              }

              Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 1
                color: Qt.alpha(Color.mOnSurface, 0.06)
              }

              // ── Rebuild ───────────────────────────────
              ColumnLayout {
                Layout.fillWidth: true
                spacing: Style.marginS

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
              }

              Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 1
                color: Qt.alpha(Color.mOnSurface, 0.06)
              }

              // ── Garbage Collection ────────────────────
              ColumnLayout {
                Layout.fillWidth: true
                spacing: Style.marginS

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
                      { label: "Store Only", mode: "store", icon: "database" },
                      { label: "Dry Run", mode: "dry", icon: "eye" }
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
              }

              Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 1
                color: Qt.alpha(Color.mOnSurface, 0.06)
              }

              // ── Git ───────────────────────────────────
              ColumnLayout {
                Layout.fillWidth: true
                spacing: Style.marginS

                NText {
                  text: "Git"
                  pointSize: Style.fontSizeS
                  font.weight: Style.fontWeightBold
                  color: Color.mPrimary
                }

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
                    text: "Push"
                    icon: "git-branch"
                    enabled: !root.isRunning && (root.repoInfo?.ahead ?? 0) > 0
                    onClicked: {
                      if (mainInstance) mainInstance.runActionSilent("git-push")
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
                        // Push after short delay for commit to complete
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
    }
  }
}
