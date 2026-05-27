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
  readonly property var arrivals: mainInstance?.arrivals ?? []
  readonly property string stopName: mainInstance?.stopName ?? ""
  readonly property bool isRefreshing: mainInstance?.isRefreshing ?? false

  readonly property bool panelReady: pluginApi !== null && mainInstance !== null && mainInstance !== undefined

  property real contentPreferredWidth: panelReady ? 350 * Style.uiScaleRatio : 0
  property real contentPreferredHeight: panelReady ? Math.min(500, Math.max(150, 80 + arrivals.length * 60 + 20)) * Style.uiScaleRatio : 0

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
          spacing: Style.marginM
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

            ColumnLayout {
              Layout.fillWidth: true
              spacing: 0

              NText {
                text: "Bus Arrivals"
                pointSize: Style.fontSizeL
                font.weight: Style.fontWeightBold
                color: Color.mOnSurface
              }

              NText {
                text: root.stopName
                visible: root.stopName !== ""
                pointSize: Style.fontSizeXS
                color: Color.mOnSurfaceVariant
                elide: Text.ElideRight
                Layout.fillWidth: true
              }
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

          // Arrivals list
          Flickable {
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            contentWidth: width
            contentHeight: arrivalColumn.implicitHeight
            interactive: contentHeight > height
            boundsBehavior: Flickable.StopAtBounds

            ColumnLayout {
              id: arrivalColumn
              width: parent.width
              spacing: Style.marginS

              Repeater {
                model: root.arrivals

                delegate: Item {
                  id: arrivalDelegate
                  Layout.fillWidth: true
                  Layout.preferredHeight: arrivalRow.implicitHeight + Style.marginM * 2

                  readonly property var arrival: modelData
                  readonly property bool isRealtime: arrival.realtime || false
                  readonly property color liveColor: Color.mPrimary
                  readonly property color schedColor: Qt.alpha(Color.mOnSurfaceVariant, 0.5)
                  readonly property color statusColor: isRealtime ? liveColor : schedColor

                  RowLayout {
                    id: arrivalRow
                    anchors {
                      left: parent.left
                      right: parent.right
                      verticalCenter: parent.verticalCenter
                      margins: Style.marginM
                    }
                    spacing: Style.marginM

                    // Live indicator dot
                    Rectangle {
                      width: 10
                      height: 10
                      radius: 5
                      color: arrivalDelegate.isRealtime ? arrivalDelegate.liveColor : "transparent"
                      border.width: arrivalDelegate.isRealtime ? 0 : 2
                      border.color: arrivalDelegate.schedColor
                      Layout.alignment: Qt.AlignVCenter
                    }

                    // Line number badge
                    Rectangle {
                      implicitWidth: Math.max(lineText.implicitWidth + Style.marginM * 2, 44)
                      implicitHeight: lineText.implicitHeight + Style.marginS
                      radius: Style.radiusS
                      color: Qt.alpha(arrivalDelegate.statusColor, arrivalDelegate.isRealtime ? 0.15 : 0.08)
                      Layout.alignment: Qt.AlignVCenter

                      NText {
                        id: lineText
                        anchors.centerIn: parent
                        text: arrivalDelegate.arrival.line || ""
                        pointSize: Style.fontSizeM
                        font.weight: Style.fontWeightBold
                        color: arrivalDelegate.statusColor
                        font.family: Settings.data.ui.fontFixed
                      }
                    }

                    // Destination
                    NText {
                      text: arrivalDelegate.arrival.destination || ""
                      pointSize: Style.fontSizeS
                      color: arrivalDelegate.isRealtime ? Color.mOnSurface : Qt.alpha(Color.mOnSurface, 0.5)
                      elide: Text.ElideRight
                      Layout.fillWidth: true
                    }

                    // ETA
                    ColumnLayout {
                      spacing: 0
                      Layout.alignment: Qt.AlignVCenter | Qt.AlignRight

                      NText {
                        text: arrivalDelegate.arrival.eta === 0 ? "Now" : arrivalDelegate.arrival.eta + " min"
                        pointSize: Style.fontSizeM
                        font.weight: Style.fontWeightBold
                        color: {
                          if (!arrivalDelegate.isRealtime) return Qt.alpha(Color.mOnSurface, 0.4)
                          if (arrivalDelegate.arrival.eta <= 2) return Color.mError
                          if (arrivalDelegate.arrival.eta <= 5) return "#F59E0B"
                          return Color.mOnSurface
                        }
                        font.family: Settings.data.ui.fontFixed
                        horizontalAlignment: Text.AlignRight
                      }

                      NText {
                        text: {
                          var time = arrivalDelegate.arrival.etaTime || ""
                          return arrivalDelegate.isRealtime ? time : time + " (sched)"
                        }
                        pointSize: Style.fontSizeXS
                        color: Color.mOnSurfaceVariant
                        font.family: Settings.data.ui.fontFixed
                        horizontalAlignment: Text.AlignRight
                      }
                    }
                  }
                }
              }

              // Empty state
              NText {
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignHCenter
                Layout.topMargin: Style.marginL
                text: "No upcoming buses"
                visible: root.arrivals.length === 0
                pointSize: Style.fontSizeM
                color: Color.mOnSurfaceVariant
                horizontalAlignment: Text.AlignHCenter
              }
            }
          }
        }
      }
    }
  }
}
