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
  readonly property var stopData1: mainInstance?.stopData1 ?? null
  readonly property var stopData2: mainInstance?.stopData2 ?? null
  readonly property var connections: mainInstance?.connections ?? []
  readonly property bool isRefreshing: mainInstance?.isRefreshing ?? false

  readonly property bool panelReady: pluginApi !== null && mainInstance !== null && mainInstance !== undefined
  readonly property bool hasStop2: stopData2 !== null && (stopData2.code || "") !== ""

  property real contentPreferredWidth: panelReady ? 380 * Style.uiScaleRatio : 0
  property real contentPreferredHeight: {
    if (!panelReady) return 0
    var h = 60 // header
    var s1Lines = stopData1 ? (stopData1.lines || []).length : 0
    var s2Lines = hasStop2 ? (stopData2.lines || []).length : 0
    h += 30 + s1Lines * 36 // stop1 header + lines
    if (hasStop2) h += 30 + s2Lines * 36 // stop2 header + lines
    if (connections.length > 0) h += 30 + connections.length * 50 // connections
    return Math.min(600, Math.max(150, h)) * Style.uiScaleRatio
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

            NText {
              text: "Bus Tracker"
              pointSize: Style.fontSizeL
              font.weight: Style.fontWeightBold
              color: Color.mOnSurface
              Layout.fillWidth: true
            }

            NIcon {
              visible: root.isRefreshing
              icon: "refresh"
              pointSize: Style.fontSizeS
              color: Color.mOnSurfaceVariant
            }
          }

          Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 1
            color: Qt.alpha(Color.mOnSurface, 0.1)
          }

          // Scrollable content
          Flickable {
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            contentWidth: width
            contentHeight: mainColumn.implicitHeight
            interactive: contentHeight > height
            boundsBehavior: Flickable.StopAtBounds

            ColumnLayout {
              id: mainColumn
              width: parent.width
              spacing: Style.marginM

              // ── Stop 1 ──────────────────────────────────
              ColumnLayout {
                Layout.fillWidth: true
                spacing: Style.marginS
                visible: root.stopData1 !== null

                NText {
                  text: root.stopData1?.name || ("Stop " + (root.stopData1?.code || ""))
                  pointSize: Style.fontSizeS
                  font.weight: Style.fontWeightBold
                  color: Color.mPrimary
                }

                Repeater {
                  model: root.stopData1?.lines || []

                  delegate: Item {
                    id: s1LineDelegate
                    Layout.fillWidth: true
                    Layout.preferredHeight: s1LineRow.implicitHeight
                    readonly property var lineData: modelData

                    RowLayout {
                      id: s1LineRow
                      anchors.left: parent.left
                      anchors.right: parent.right
                      spacing: Style.marginS

                      Rectangle {
                        implicitWidth: Math.max(s1Badge.implicitWidth + Style.marginS * 2, 40)
                        implicitHeight: s1Badge.implicitHeight + 4
                        radius: Style.radiusS
                        color: Qt.alpha(s1LineDelegate.lineData.active ? Color.mPrimary : Color.mOnSurfaceVariant, s1LineDelegate.lineData.active ? 0.15 : 0.08)

                        NText {
                          id: s1Badge
                          anchors.centerIn: parent
                          text: s1LineDelegate.lineData.line || ""
                          pointSize: Style.fontSizeS
                          font.weight: Style.fontWeightBold
                          color: s1LineDelegate.lineData.active ? Color.mPrimary : Qt.alpha(Color.mOnSurfaceVariant, 0.5)
                          font.family: Settings.data.ui.fontFixed
                        }
                      }

                      Repeater {
                        model: s1LineDelegate.lineData.arrivals || []

                        delegate: Rectangle {
                          readonly property var arr: modelData
                          implicitWidth: s1Time.implicitWidth + Style.marginS * 2
                          implicitHeight: s1Time.implicitHeight + 4
                          radius: Style.radiusS
                          color: Qt.alpha(arr.realtime ? Color.mPrimary : Color.mOnSurfaceVariant, arr.realtime ? 0.12 : 0.06)

                          NText {
                            id: s1Time
                            anchors.centerIn: parent
                            text: parent.arr.eta === 0 ? "Now" : parent.arr.eta + "m"
                            pointSize: Style.fontSizeS
                            font.weight: Style.fontWeightMedium
                            color: {
                              if (!parent.arr.realtime) return Qt.alpha(Color.mOnSurfaceVariant, 0.6)
                              if (parent.arr.eta <= 2) return Color.mError
                              if (parent.arr.eta <= 5) return "#F59E0B"
                              return Color.mPrimary
                            }
                            font.family: Settings.data.ui.fontFixed
                          }
                        }
                      }

                      NText {
                        visible: (s1LineDelegate.lineData.arrivals || []).length === 0
                        text: "no service"
                        pointSize: Style.fontSizeXS
                        color: Qt.alpha(Color.mOnSurfaceVariant, 0.4)
                      }

                      Item { Layout.fillWidth: true }
                    }
                  }
                }
              }

              // ── Connections ──────────────────────────────
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

                        // Board line badge
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

                        // Catchable lines
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

              // ── Stop 2 ──────────────────────────────────
              ColumnLayout {
                Layout.fillWidth: true
                spacing: Style.marginS
                visible: root.hasStop2

                Rectangle {
                  Layout.fillWidth: true
                  Layout.preferredHeight: 1
                  color: Qt.alpha(Color.mOnSurface, 0.1)
                }

                NText {
                  text: root.stopData2?.name || ("Stop " + (root.stopData2?.code || ""))
                  pointSize: Style.fontSizeS
                  font.weight: Style.fontWeightBold
                  color: Color.mOnSurfaceVariant
                }

                Repeater {
                  model: root.stopData2?.lines || []

                  delegate: Item {
                    id: s2LineDelegate
                    Layout.fillWidth: true
                    Layout.preferredHeight: s2LineRow.implicitHeight
                    readonly property var lineData: modelData

                    RowLayout {
                      id: s2LineRow
                      anchors.left: parent.left
                      anchors.right: parent.right
                      spacing: Style.marginS

                      Rectangle {
                        implicitWidth: Math.max(s2Badge.implicitWidth + Style.marginS * 2, 40)
                        implicitHeight: s2Badge.implicitHeight + 4
                        radius: Style.radiusS
                        color: Qt.alpha(s2LineDelegate.lineData.active ? Color.mTertiary : Color.mOnSurfaceVariant, s2LineDelegate.lineData.active ? 0.15 : 0.08)

                        NText {
                          id: s2Badge
                          anchors.centerIn: parent
                          text: s2LineDelegate.lineData.line || ""
                          pointSize: Style.fontSizeS
                          font.weight: Style.fontWeightBold
                          color: s2LineDelegate.lineData.active ? Color.mTertiary : Qt.alpha(Color.mOnSurfaceVariant, 0.5)
                          font.family: Settings.data.ui.fontFixed
                        }
                      }

                      Repeater {
                        model: s2LineDelegate.lineData.arrivals || []

                        delegate: Rectangle {
                          readonly property var arr: modelData
                          implicitWidth: s2Time.implicitWidth + Style.marginS * 2
                          implicitHeight: s2Time.implicitHeight + 4
                          radius: Style.radiusS
                          color: Qt.alpha(arr.realtime ? Color.mTertiary : Color.mOnSurfaceVariant, arr.realtime ? 0.12 : 0.06)

                          NText {
                            id: s2Time
                            anchors.centerIn: parent
                            text: parent.arr.eta === 0 ? "Now" : parent.arr.eta + "m"
                            pointSize: Style.fontSizeS
                            font.weight: Style.fontWeightMedium
                            color: {
                              if (!parent.arr.realtime) return Qt.alpha(Color.mOnSurfaceVariant, 0.6)
                              if (parent.arr.eta <= 2) return Color.mError
                              if (parent.arr.eta <= 5) return "#F59E0B"
                              return Color.mTertiary
                            }
                            font.family: Settings.data.ui.fontFixed
                          }
                        }
                      }

                      NText {
                        visible: (s2LineDelegate.lineData.arrivals || []).length === 0
                        text: "no service"
                        pointSize: Style.fontSizeXS
                        color: Qt.alpha(Color.mOnSurfaceVariant, 0.4)
                      }

                      Item { Layout.fillWidth: true }
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
