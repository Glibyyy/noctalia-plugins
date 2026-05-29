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
  readonly property int nextEta: mainInstance?.nextEta ?? -1
  readonly property string nextLine: mainInstance?.nextLine ?? ""
  readonly property bool hasData: nextEta >= 0
  readonly property bool hasError: mainInstance?.hasError ?? false

  readonly property real contentWidth: {
    if (!hasData && !hasError) return Style.capsuleHeight
    return contentRow.implicitWidth + Style.marginM * 2
  }
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
        icon: root.hasError ? "warning" : "bus"
        pointSize: Style.fontSizeL
        color: {
          if (root.hasError) return Color.mError
          if (!root.hasData) return Color.mOnSurfaceVariant
          if (root.nextEta <= 2) return Color.mError
          if (root.nextEta <= 5) return "#F59E0B"
          return Color.mPrimary
        }
      }

      NText {
        visible: root.hasData && !root.hasError
        text: root.nextLine + " " + root.nextEta + "m"
        pointSize: Style.fontSizeS
        font.weight: Style.fontWeightBold
        color: {
          if (mouseArea.containsMouse) return Color.mOnHover
          if (root.nextEta <= 2) return Color.mError
          if (root.nextEta <= 5) return "#F59E0B"
          return Color.mOnSurface
        }
        font.family: Settings.data.ui.fontFixed
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
