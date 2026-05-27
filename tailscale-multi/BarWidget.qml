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

  readonly property bool pillDirection: BarService.getPillDirection(root)
  readonly property var mainInstance: pluginApi?.mainInstance
  readonly property bool anyConnected: mainInstance?.anyConnected ?? false
  readonly property bool isRefreshing: mainInstance?.isRefreshing ?? false

  readonly property real contentWidth: {
    if ((mainInstance?.compactMode ?? true) || !anyConnected) {
      return Style.capsuleHeight
    }
    return contentRow.implicitWidth + Style.marginM * 2
  }
  readonly property real contentHeight: Style.capsuleHeight

  implicitWidth: contentWidth
  implicitHeight: contentHeight

  Rectangle {
    id: visualCapsule
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
      layoutDirection: Qt.LeftToRight

      TailscaleIcon {
        pointSize: Style.fontSizeL
        applyUiScale: false
        connected: root.anyConnected
        connecting: root.isRefreshing && !root.anyConnected
        hovered: mouseArea.containsMouse
        litColor: Color.mPrimary
      }

      NText {
        visible: !(mainInstance?.compactMode ?? true) && root.anyConnected
        text: (mainInstance?.connectedCount ?? 0) + "/" + (mainInstance?.totalCount ?? 0)
        pointSize: Style.fontSizeXS
        color: mouseArea.containsMouse ? Color.mOnHover : Color.mOnSurface
        font.family: Settings.data.ui.fontFixed
      }
    }
  }

  NPopupContextMenu {
    id: contextMenu
    model: [
      {
        "label": "Settings",
        "action": "widget-settings",
        "icon": "settings"
      }
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
