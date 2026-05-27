import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.Commons
import qs.Widgets

ColumnLayout {
  id: root

  property var pluginApi: null

  property string editStop1Code: pluginApi?.pluginSettings?.stop1?.code || "21477"
  property string editStop1Lines: (pluginApi?.pluginSettings?.stop1?.lines || ["33", "32", "54"]).join(", ")
  property string editStop2Code: pluginApi?.pluginSettings?.stop2?.code || "21450"
  property string editStop2Lines: (pluginApi?.pluginSettings?.stop2?.lines || ["32", "33", "42", "54", "525", "531", "621"]).join(", ")
  property int editRefreshInterval: pluginApi?.pluginSettings?.refreshInterval || 30000

  spacing: Style.marginM

  NText {
    text: "Bus Tracker"
    font.pointSize: Style.fontSizeXL
    font.bold: true
  }

  NText {
    text: "Dual-stop bus tracker with transfer analysis"
    color: Color.mSecondary
    Layout.fillWidth: true
    wrapMode: Text.Wrap
  }

  NDivider { Layout.fillWidth: true; Layout.topMargin: Style.marginM; Layout.bottomMargin: Style.marginM }

  NLabel { label: "Stop 1 (Origin)"; description: "Your starting bus stop" }

  NTextInput {
    Layout.fillWidth: true
    label: "Stop Code"
    placeholderText: "21477"
    text: root.editStop1Code
    onTextChanged: root.editStop1Code = text
  }

  NTextInput {
    Layout.fillWidth: true
    label: "Lines"
    placeholderText: "33, 32, 54"
    text: root.editStop1Lines
    onTextChanged: root.editStop1Lines = text
  }

  NDivider { Layout.fillWidth: true; Layout.topMargin: Style.marginM; Layout.bottomMargin: Style.marginM }

  NLabel { label: "Stop 2 (Transfer)"; description: "Where you transfer — shared lines are tracked for connections" }

  NTextInput {
    Layout.fillWidth: true
    label: "Stop Code"
    placeholderText: "21450"
    text: root.editStop2Code
    onTextChanged: root.editStop2Code = text
  }

  NTextInput {
    Layout.fillWidth: true
    label: "Lines"
    placeholderText: "32, 33, 42, 54, 525, 531, 621"
    text: root.editStop2Lines
    onTextChanged: root.editStop2Lines = text
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

    var l1 = root.editStop1Lines.split(",").map(function(s) { return s.trim() }).filter(function(s) { return s !== "" })
    var l2 = root.editStop2Lines.split(",").map(function(s) { return s.trim() }).filter(function(s) { return s !== "" })

    pluginApi.pluginSettings.stop1 = { code: root.editStop1Code.trim(), lines: l1 }
    pluginApi.pluginSettings.stop2 = { code: root.editStop2Code.trim(), lines: l2 }
    pluginApi.pluginSettings.refreshInterval = root.editRefreshInterval

    pluginApi.saveSettings()
  }
}
