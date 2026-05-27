import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.Commons
import qs.Widgets

ColumnLayout {
  id: root

  property var pluginApi: null

  property string editStopCode:
    pluginApi?.pluginSettings?.stopCode || "21477"

  property string editLines:
    (pluginApi?.pluginSettings?.lines || ["32", "33", "54"]).join(", ")

  property int editRefreshInterval:
    pluginApi?.pluginSettings?.refreshInterval || 30000

  spacing: Style.marginM

  NText {
    text: "Bus Tracker"
    font.pointSize: Style.fontSizeXL
    font.bold: true
  }

  NText {
    text: "Live bus arrival times from curlbus.app"
    color: Color.mSecondary
    Layout.fillWidth: true
    wrapMode: Text.Wrap
  }

  NDivider { Layout.fillWidth: true; Layout.topMargin: Style.marginM; Layout.bottomMargin: Style.marginM }

  NTextInput {
    Layout.fillWidth: true
    label: "Stop Code"
    description: "The bus stop number (e.g. 21477)"
    placeholderText: "21477"
    text: root.editStopCode
    onTextChanged: root.editStopCode = text
  }

  NTextInput {
    Layout.fillWidth: true
    label: "Lines"
    description: "Comma-separated line numbers (blank = all lines)"
    placeholderText: "32, 33, 54"
    text: root.editLines
    onTextChanged: root.editLines = text
  }

  NDivider { Layout.fillWidth: true; Layout.topMargin: Style.marginM; Layout.bottomMargin: Style.marginM }

  NLabel {
    label: "Refresh Interval"
    description: "How often to poll (" + root.editRefreshInterval / 1000 + "s)"
  }

  NSlider {
    Layout.fillWidth: true
    from: 10000
    to: 120000
    stepSize: 5000
    value: root.editRefreshInterval
    onValueChanged: root.editRefreshInterval = value
  }

  function saveSettings() {
    if (!pluginApi) return

    var lineList = root.editLines.split(",").map(function(s) { return s.trim() }).filter(function(s) { return s !== "" })

    pluginApi.pluginSettings.stopCode = root.editStopCode
    pluginApi.pluginSettings.lines = lineList
    pluginApi.pluginSettings.refreshInterval = root.editRefreshInterval

    pluginApi.saveSettings()
  }
}
