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
  readonly property var busLines: mainInstance?.busLines ?? []
  readonly property string stopName: mainInstance?.stopName ?? ""
  readonly property bool isRefreshing: mainInstance?.isRefreshing ?? false

  readonly property bool panelReady: pluginApi !== null && mainInstance !== null && mainInstance !== undefined

  property real contentPreferredWidth: panelReady ? 380 * Style.uiScaleRatio : 0
  property real contentPreferredHeight: panelReady ? Math.min(400, 80 + busLines.length * 56 + 20) * Style.uiScaleRatio : 0

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
          }

          Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 1
            color: Qt.alpha(Color.mOnSurface, 0.1)
          }

          // Bus lines
          Flickable {
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            contentWidth: width
            contentHeight: linesColumn.implicitHeight
            interactive: contentHeight > height
            boundsBehavior: Flickable.StopAtBounds

            ColumnLayout {
              id: linesColumn
              width: parent.width
              spacing: Style.marginM

              Repeater {
                model: root.busLines

                delegate: Item {
                  id: lineDelegate
                  Layout.fillWidth: true
                  Layout.preferredHeight: lineRow.implicitHeight

                  readonly property var lineData: modelData
                  readonly property bool isActive: lineData.active || false
                  readonly property var arrivals: lineData.arrivals || []

                  RowLayout {
                    id: lineRow
                    anchors.left: parent.left
                    anchors.right: parent.right
                    spacing: Style.marginM

                    // Line number badge
                    Rectangle {
                      implicitWidth: Math.max(lineBadgeText.implicitWidth + Style.marginM * 2, 44)
                      implicitHeight: lineBadgeText.implicitHeight + Style.marginS * 2
                      radius: Style.radiusS
                      color: Qt.alpha(lineDelegate.isActive ? Color.mPrimary : Color.mOnSurfaceVariant, lineDelegate.isActive ? 0.15 : 0.08)
                      Layout.alignment: Qt.AlignVCenter

                      NText {
                        id: lineBadgeText
                        anchors.centerIn: parent
                        text: lineDelegate.lineData.line || ""
                        pointSize: Style.fontSizeM
                        font.weight: Style.fontWeightBold
                        color: lineDelegate.isActive ? Color.mPrimary : Qt.alpha(Color.mOnSurfaceVariant, 0.5)
                        font.family: Settings.data.ui.fontFixed
                      }
                    }

                    // Times row
                    RowLayout {
                      Layout.fillWidth: true
                      Layout.alignment: Qt.AlignVCenter
                      spacing: Style.marginS

                      Repeater {
                        model: lineDelegate.arrivals

                        delegate: Rectangle {
                          id: timeBadge
                          readonly property var arr: modelData
                          readonly property bool isRealtime: arr.realtime || false

                          implicitWidth: timeText.implicitWidth + Style.marginS * 2
                          implicitHeight: timeText.implicitHeight + 4
                          radius: Style.radiusS
                          color: isRealtime
                            ? Qt.alpha(Color.mPrimary, 0.12)
                            : Qt.alpha(Color.mOnSurfaceVariant, 0.08)

                          NText {
                            id: timeText
                            anchors.centerIn: parent
                            text: timeBadge.arr.eta === 0 ? "Now" : timeBadge.arr.eta + "m"
                            pointSize: Style.fontSizeS
                            font.weight: Style.fontWeightMedium
                            color: {
                              if (!timeBadge.isRealtime) return Qt.alpha(Color.mOnSurfaceVariant, 0.6)
                              if (timeBadge.arr.eta <= 2) return Color.mError
                              if (timeBadge.arr.eta <= 5) return "#F59E0B"
                              return Color.mPrimary
                            }
                            font.family: Settings.data.ui.fontFixed
                          }
                        }
                      }

                      // No service indicator
                      NText {
                        visible: lineDelegate.arrivals.length === 0
                        text: "no service"
                        pointSize: Style.fontSizeXS
                        color: Qt.alpha(Color.mOnSurfaceVariant, 0.4)
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
