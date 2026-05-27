import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.Commons
import qs.Widgets
import qs.Services.UI

Item {
  id: root

  property var pluginApi: null
  property ShellScreen screen
  property string widgetId: ""
  property string section: ""
  property int sectionWidgetIndex: -1
  property int sectionWidgetsCount: 0

  readonly property var mainInstance: pluginApi?.mainInstance
  readonly property string genNumber: mainInstance?.genNumber ?? "?"
  readonly property string barStatus: mainInstance?.barStatus ?? "clean"

  readonly property color statusColor: {
    if (barStatus === "behind") return "#F59E0B"
    if (barStatus === "dirty") return Color.mTertiary
    return Color.mPrimary
  }

  readonly property real contentWidth: contentRow.implicitWidth + Style.marginM * 2
  readonly property real contentHeight: Style.capsuleHeight

  implicitWidth: contentWidth
  implicitHeight: contentHeight

  Rectangle {
    x: Style.pixelAlignCenter(parent.width, width)
    y: Style.pixelAlignCenter(parent.height, height)
    width: root.contentWidth
    height: root.contentHeight
    color: mouseArea.containsMouse ? Color.mHover : Style.capsuleColor
    radius: Style.radiusL

    RowLayout {
      id: contentRow
      anchors.centerIn: parent
      spacing: Style.marginS

      NIcon {
        icon: "snowflake"
        pointSize: Style.fontSizeL
        color: root.statusColor
      }

      NText {
        text: "G" + root.genNumber
        pointSize: Style.fontSizeS
        font.weight: Style.fontWeightBold
        color: mouseArea.containsMouse ? Color.mOnHover : Color.mOnSurface
        font.family: Settings.data.ui.fontFixed
      }

      // Behind indicator
      NText {
        visible: root.barStatus === "behind"
        text: "\u2193"
        pointSize: Style.fontSizeS
        color: "#F59E0B"
      }

      // Dirty indicator
      Rectangle {
        visible: root.barStatus === "dirty"
        width: 6
        height: 6
        radius: 3
        color: Color.mTertiary
      }
    }
  }

  NPopupContextMenu {
    id: contextMenu
    model: [
      { "label": "Settings", "action": "widget-settings", "icon": "settings" }
    ]
    onTriggered: action => {
      contextMenu.close()
      PanelService.closeContextMenu(screen)
      if (action === "widget-settings") {
        BarService.openPluginSettings(screen, pluginApi.manifest)
      }
    }
  }

  MouseArea {
    id: mouseArea
    anchors.fill: parent
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    acceptedButtons: Qt.LeftButton | Qt.RightButton
    onClicked: (mouse) => {
      if (mouse.button === Qt.LeftButton) {
        if (pluginApi) pluginApi.openPanel(root.screen, root)
      } else if (mouse.button === Qt.RightButton) {
        PanelService.showContextMenu(contextMenu, root, screen)
      }
    }
  }
}
