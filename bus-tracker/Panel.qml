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
  readonly property var stopsData: mainInstance?.stopsData ?? []
  readonly property var connections: mainInstance?.connections ?? []
  readonly property bool isRefreshing: mainInstance?.isRefreshing ?? false
  readonly property bool hasError: mainInstance?.hasError ?? false
  readonly property string lastUpdated: mainInstance?.lastUpdated ?? ""
  readonly property var profiles: mainInstance?.profiles ?? []
  readonly property int activeProfile: mainInstance?.activeProfile ?? -1
  readonly property var trackedNotification: mainInstance?.trackedNotification ?? null

  readonly property bool panelReady: pluginApi !== null && mainInstance !== null && mainInstance !== undefined
  readonly property bool hasStops: stopsData.length > 0
  readonly property bool hasAnyData: {
    if (!hasStops) return false
    for (var i = 0; i < stopsData.length; i++) {
      var lines = stopsData[i].lines || []
      for (var j = 0; j < lines.length; j++) {
        if ((lines[j].arrivals || []).length > 0) return true
      }
    }
    return false
  }

  property real contentPreferredWidth: panelReady ? 380 * Style.uiScaleRatio : 0
  property real contentPreferredHeight: {
    if (!panelReady) return 0
    var h = 60 // header
    if (!hasStops) return Math.max(150, h + 80) * Style.uiScaleRatio

    for (var i = 0; i < stopsData.length; i++) {
      var sLines = stopsData[i].lines || []
      h += 30 + sLines.length * 48 // stop header + lines (taller for destination row)
    }
    if (connections.length > 0) h += 30 + connections.length * 50
    return Math.min(700, Math.max(150, h)) * Style.uiScaleRatio
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
              icon: "bus"
              pointSize: Style.fontSizeL
              color: Color.mPrimary
            }

            // Profile dropdown
            NText {
              visible: root.profiles.length <= 1
              text: root.profiles.length === 1 ? (root.profiles[0].name || "Bus Tracker") : "Bus Tracker"
              pointSize: Style.fontSizeL
              font.weight: Style.fontWeightBold
              color: Color.mOnSurface
              Layout.fillWidth: true
            }

            Rectangle {
              visible: root.profiles.length > 1
              Layout.fillWidth: true
              implicitHeight: profileDropdown.implicitHeight
              color: "transparent"

              RowLayout {
                id: profileDropdown
                anchors.left: parent.left
                anchors.right: parent.right
                spacing: Style.marginS

                NText {
                  text: (root.activeProfile >= 0 && root.activeProfile < root.profiles.length)
                        ? (root.profiles[root.activeProfile].name || "Profile " + (root.activeProfile + 1))
                        : "Bus Tracker"
                  pointSize: Style.fontSizeL
                  font.weight: Style.fontWeightBold
                  color: Color.mOnSurface
                }

                NIcon {
                  icon: "expand-more"
                  pointSize: Style.fontSizeS
                  color: Color.mOnSurfaceVariant
                }

                Item { Layout.fillWidth: true }

                MouseArea {
                  anchors.fill: parent
                  cursorShape: Qt.PointingHandCursor
                  onClicked: profileMenu.open()
                }
              }

              NPopupContextMenu {
                id: profileMenu
                model: {
                  var items = []
                  for (var i = 0; i < root.profiles.length; i++) {
                    items.push({
                      "label": root.profiles[i].name || ("Profile " + (i + 1)),
                      "action": "profile_" + i,
                      "icon": i === root.activeProfile ? "check" : ""
                    })
                  }
                  return items
                }
                onTriggered: action => {
                  profileMenu.close()
                  var idx = parseInt(action.replace("profile_", ""))
                  if (!isNaN(idx) && root.mainInstance) {
                    root.mainInstance.switchProfile(idx)
                  }
                }
              }
            }

            NText {
              visible: root.lastUpdated !== "" && !root.hasError
              text: root.lastUpdated
              pointSize: Style.fontSizeXS
              color: Color.mOnSurfaceVariant
              font.family: Settings.data.ui.fontFixed
            }

            NIcon {
              visible: root.hasError
              icon: "warning"
              pointSize: Style.fontSizeS
              color: Color.mError
            }

            NIcon {
              visible: root.isRefreshing && !root.hasError
              icon: "refresh"
              pointSize: Style.fontSizeS
              color: Color.mOnSurfaceVariant

              RotationAnimation on rotation {
                from: 0
                to: 360
                duration: 1000
                loops: Animation.Infinite
                running: root.isRefreshing
              }
            }
          }

          Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 1
            color: Qt.alpha(Color.mOnSurface, 0.1)
          }

          // No data state
          ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            visible: !root.hasStops || (!root.hasAnyData && !root.hasError)
            spacing: Style.marginM

            Item { Layout.fillHeight: true }

            NIcon {
              Layout.alignment: Qt.AlignHCenter
              icon: root.hasStops ? "schedule" : "add-circle-outline"
              pointSize: 32
              color: Qt.alpha(Color.mOnSurfaceVariant, 0.3)
            }

            NText {
              Layout.alignment: Qt.AlignHCenter
              text: {
                if (!root.hasStops) return "No stops configured"
                var now = new Date()
                var hour = now.getHours()
                var mi = root.mainInstance
                if (mi && (hour < mi.activeHoursStart || hour >= mi.activeHoursEnd))
                  return "Outside active hours (" + mi.activeHoursStart + ":00–" + mi.activeHoursEnd + ":00)"
                return "No buses right now"
              }
              pointSize: Style.fontSizeS
              color: Qt.alpha(Color.mOnSurfaceVariant, 0.5)
            }

            NText {
              Layout.alignment: Qt.AlignHCenter
              visible: !root.hasStops
              text: "Open settings to add stops"
              pointSize: Style.fontSizeXS
              color: Qt.alpha(Color.mOnSurfaceVariant, 0.3)
            }

            Item { Layout.fillHeight: true }
          }

          // Scrollable content
          Flickable {
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            visible: root.hasStops && (root.hasAnyData || root.hasError)
            contentWidth: width
            contentHeight: mainColumn.implicitHeight
            interactive: contentHeight > height
            boundsBehavior: Flickable.StopAtBounds

            ColumnLayout {
              id: mainColumn
              width: parent.width
              spacing: Style.marginM

              // Dynamic stops
              Repeater {
                model: root.stopsData

                delegate: ColumnLayout {
                  id: stopDelegate
                  Layout.fillWidth: true
                  spacing: Style.marginS

                  readonly property var stopInfo: modelData
                  readonly property int stopIndex: index
                  readonly property bool isFirstStop: index === 0

                  // Separator between stops
                  Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 1
                    visible: stopDelegate.stopIndex > 0
                    color: Qt.alpha(Color.mOnSurface, 0.1)
                  }

                  NText {
                    text: stopDelegate.stopInfo.name || ("Stop " + (stopDelegate.stopInfo.code || ""))
                    pointSize: Style.fontSizeS
                    font.weight: Style.fontWeightBold
                    color: stopDelegate.isFirstStop ? Color.mPrimary : Color.mOnSurfaceVariant
                  }

                  Repeater {
                    model: stopDelegate.stopInfo.lines || []

                    delegate: Item {
                      id: lineDelegate
                      Layout.fillWidth: true
                      Layout.preferredHeight: lineColumn.implicitHeight
                      readonly property var lineData: modelData
                      readonly property int lineIdx: index

                      ColumnLayout {
                        id: lineColumn
                        anchors.left: parent.left
                        anchors.right: parent.right
                        spacing: 2

                        RowLayout {
                          spacing: Style.marginS

                          Rectangle {
                            implicitWidth: Math.max(lineBadge.implicitWidth + Style.marginS * 2, 40)
                            implicitHeight: lineBadge.implicitHeight + 4
                            radius: Style.radiusS
                            color: Qt.alpha(
                              lineDelegate.lineData.active
                                ? (stopDelegate.isFirstStop ? Color.mPrimary : Color.mTertiary)
                                : Color.mOnSurfaceVariant,
                              lineDelegate.lineData.active ? 0.15 : 0.08
                            )

                            NText {
                              id: lineBadge
                              anchors.centerIn: parent
                              text: lineDelegate.lineData.line || ""
                              pointSize: Style.fontSizeS
                              font.weight: Style.fontWeightBold
                              color: lineDelegate.lineData.active
                                ? (stopDelegate.isFirstStop ? Color.mPrimary : Color.mTertiary)
                                : Qt.alpha(Color.mOnSurfaceVariant, 0.5)
                              font.family: Settings.data.ui.fontFixed
                            }
                          }

                          Repeater {
                            model: lineDelegate.lineData.arrivals || []

                            delegate: Rectangle {
                              id: arrivalChip
                              readonly property var arr: modelData
                              readonly property int arrIdx: index
                              readonly property bool isTracked: {
                                var tn = root.trackedNotification
                                if (!tn) return false
                                return tn.line === lineDelegate.lineData.line
                                    && tn.stopIndex === stopDelegate.stopIndex
                                    && tn.arrivalIndex === arrIdx
                              }

                              implicitWidth: arrTime.implicitWidth + Style.marginS * 2
                              implicitHeight: arrTime.implicitHeight + 4
                              radius: Style.radiusS
                              border.width: isTracked ? 2 : 0
                              border.color: "#F59E0B"
                              color: {
                                if (isTracked) return Qt.alpha("#F59E0B", 0.2)
                                var accent = stopDelegate.isFirstStop ? Color.mPrimary : Color.mTertiary
                                return Qt.alpha(arr.realtime ? accent : Color.mOnSurfaceVariant, arr.realtime ? 0.12 : 0.06)
                              }

                              NText {
                                id: arrTime
                                anchors.centerIn: parent
                                text: parent.arr.eta === 0 ? "Now" : parent.arr.eta + "m"
                                pointSize: Style.fontSizeS
                                font.weight: Style.fontWeightMedium
                                color: {
                                  if (parent.isTracked) return "#F59E0B"
                                  if (!parent.arr.realtime) return Qt.alpha(Color.mOnSurfaceVariant, 0.6)
                                  if (parent.arr.eta <= 2) return Color.mError
                                  if (parent.arr.eta <= 5) return "#F59E0B"
                                  var accent = stopDelegate.isFirstStop ? Color.mPrimary : Color.mTertiary
                                  return accent
                                }
                                font.family: Settings.data.ui.fontFixed
                              }

                              MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                  if (!root.mainInstance) return
                                  if (arrivalChip.isTracked) {
                                    root.mainInstance.clearNotification()
                                  } else {
                                    root.mainInstance.setNotification(
                                      lineDelegate.lineData.line,
                                      stopDelegate.stopIndex,
                                      arrivalChip.arrIdx,
                                      arrivalChip.arr.eta
                                    )
                                  }
                                }
                              }
                            }
                          }

                          NText {
                            visible: (lineDelegate.lineData.arrivals || []).length === 0
                            text: "no service"
                            pointSize: Style.fontSizeXS
                            color: Qt.alpha(Color.mOnSurfaceVariant, 0.4)
                          }

                          Item { Layout.fillWidth: true }
                        }

                        // Destination row
                        NText {
                          visible: (lineDelegate.lineData.destination || "") !== ""
                          text: "→ " + (lineDelegate.lineData.destination || "")
                          pointSize: Style.fontSizeXS
                          color: Qt.alpha(Color.mOnSurfaceVariant, 0.6)
                          Layout.leftMargin: 4
                          elide: Text.ElideRight
                          Layout.maximumWidth: lineColumn.width - 8
                        }
                      }
                    }
                  }
                }
              }

              // Connections
              ColumnLayout {
                Layout.fillWidth: true
                spacing: Style.marginS
                visible: root.connections.length > 0

                Rectangle {
                  Layout.fillWidth: true
                  Layout.preferredHeight: 1
                  color: Qt.alpha(Color.mPrimary, 0.3)
                }

                NText {
                  text: "Transfers"
                  pointSize: Style.fontSizeS
                  font.weight: Style.fontWeightBold
                  color: Color.mPrimary
                }

                Repeater {
                  model: root.connections

                  delegate: Item {
                    id: connDelegate
                    Layout.fillWidth: true
                    Layout.preferredHeight: connRow.implicitHeight
                    readonly property var conn: modelData

                    ColumnLayout {
                      id: connRow
                      anchors.left: parent.left
                      anchors.right: parent.right
                      spacing: 2

                      RowLayout {
                        spacing: Style.marginS

                        Rectangle {
                          implicitWidth: connBoardText.implicitWidth + Style.marginS * 2
                          implicitHeight: connBoardText.implicitHeight + 4
                          radius: Style.radiusS
                          color: Qt.alpha(Color.mPrimary, 0.15)

                          NText {
                            id: connBoardText
                            anchors.centerIn: parent
                            text: connDelegate.conn.boardLine
                            pointSize: Style.fontSizeS
                            font.weight: Style.fontWeightBold
                            color: Color.mPrimary
                            font.family: Settings.data.ui.fontFixed
                          }
                        }

                        NText {
                          text: "in " + connDelegate.conn.boardEta + "m → " + connDelegate.conn.travelMins + "m ride →"
                          pointSize: Style.fontSizeXS
                          color: Color.mOnSurfaceVariant
                          font.family: Settings.data.ui.fontFixed
                        }

                        Repeater {
                          model: connDelegate.conn.catchable || []

                          delegate: Rectangle {
                            readonly property var c: modelData
                            implicitWidth: catchText.implicitWidth + Style.marginS * 2
                            implicitHeight: catchText.implicitHeight + 4
                            radius: Style.radiusS
                            color: Qt.alpha(c.wait <= 3 ? "#F59E0B" : Color.mTertiary, 0.15)

                            NText {
                              id: catchText
                              anchors.centerIn: parent
                              text: parent.c.line + " +" + parent.c.wait + "m"
                              pointSize: Style.fontSizeXS
                              font.weight: Style.fontWeightMedium
                              color: parent.c.wait <= 3 ? "#F59E0B" : Color.mTertiary
                              font.family: Settings.data.ui.fontFixed
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
        }
      }
    }
  }
}
