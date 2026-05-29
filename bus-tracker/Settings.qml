import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Widgets

ColumnLayout {
  id: root

  property var pluginApi: null

  // Local edit state
  property var editProfiles: []
  property int editActiveProfile: 0
  property int editRefreshInterval: 30000
  property int editActiveHoursStart: 9
  property int editActiveHoursEnd: 20
  property int editNotifyBeforeMinutes: 10

  // Search state
  property bool isSearching: false
  property var searchResults: []
  property int searchTargetProfile: -1
  property int searchTargetStop: -1

  readonly property string _pluginDir: {
    var url = Qt.resolvedUrl(".").toString()
    if (url.startsWith("file://")) url = url.substring(7)
    if (url.endsWith("/")) url = url.substring(0, url.length - 1)
    return url
  }

  Component.onCompleted: loadFromSettings()

  function loadFromSettings() {
    if (!pluginApi) return
    var s = pluginApi.pluginSettings

    var p = s?.profiles
    if (p && p.length > 0) {
      editProfiles = JSON.parse(JSON.stringify(p))
    } else {
      editProfiles = []
    }

    editActiveProfile = s?.activeProfile ?? 0
    editRefreshInterval = s?.refreshInterval ?? 30000
    editActiveHoursStart = s?.activeHoursStart ?? 9
    editActiveHoursEnd = s?.activeHoursEnd ?? 20
    editNotifyBeforeMinutes = s?.notifyBeforeMinutes ?? 10
  }

  function saveSettings() {
    if (!pluginApi) return
    pluginApi.pluginSettings.profiles = JSON.parse(JSON.stringify(editProfiles))
    pluginApi.pluginSettings.activeProfile = editActiveProfile
    pluginApi.pluginSettings.refreshInterval = editRefreshInterval
    pluginApi.pluginSettings.activeHoursStart = editActiveHoursStart
    pluginApi.pluginSettings.activeHoursEnd = editActiveHoursEnd
    pluginApi.pluginSettings.notifyBeforeMinutes = editNotifyBeforeMinutes
    pluginApi.saveSettings()
  }

  function addProfile() {
    var p = editProfiles.slice()
    p.push({ name: "Profile " + (p.length + 1), stops: [], walkTime: 5 })
    editProfiles = p
    editActiveProfile = p.length - 1
    saveSettings()
  }

  function removeProfile(idx) {
    var p = editProfiles.slice()
    p.splice(idx, 1)
    editProfiles = p
    if (editActiveProfile >= p.length) editActiveProfile = Math.max(0, p.length - 1)
    saveSettings()
  }

  function addStop(profileIdx) {
    var p = JSON.parse(JSON.stringify(editProfiles))
    p[profileIdx].stops.push({ code: "", name: "", lines: [] })
    editProfiles = p
    saveSettings()
  }

  function removeStop(profileIdx, stopIdx) {
    var p = JSON.parse(JSON.stringify(editProfiles))
    p[profileIdx].stops.splice(stopIdx, 1)
    editProfiles = p
    saveSettings()
  }

  function updateStopCode(profileIdx, stopIdx, code) {
    var p = JSON.parse(JSON.stringify(editProfiles))
    p[profileIdx].stops[stopIdx].code = code
    editProfiles = p
    saveSettings()
  }

  function updateStopName(profileIdx, stopIdx, name) {
    var p = JSON.parse(JSON.stringify(editProfiles))
    p[profileIdx].stops[stopIdx].name = name
    editProfiles = p
    saveSettings()
  }

  function updateStopLines(profileIdx, stopIdx, linesStr) {
    var p = JSON.parse(JSON.stringify(editProfiles))
    p[profileIdx].stops[stopIdx].lines = linesStr.split(",").map(function(s) { return s.trim() }).filter(function(s) { return s !== "" })
    editProfiles = p
    saveSettings()
  }

  function updateProfileName(profileIdx, name) {
    var p = JSON.parse(JSON.stringify(editProfiles))
    p[profileIdx].name = name
    editProfiles = p
    saveSettings()
  }

  function updateWalkTime(profileIdx, val) {
    var p = JSON.parse(JSON.stringify(editProfiles))
    p[profileIdx].walkTime = val
    editProfiles = p
    saveSettings()
  }

  function searchStop(query, profileIdx, stopIdx) {
    root.isSearching = true
    root.searchResults = []
    root.searchTargetProfile = profileIdx
    root.searchTargetStop = stopIdx
    searchProcess.command = ["bash", _pluginDir + "/search.sh", query]
    searchProcess.running = true
  }

  function selectSearchResult(code, name) {
    if (searchTargetProfile >= 0 && searchTargetStop >= 0) {
      updateStopCode(searchTargetProfile, searchTargetStop, code)
      updateStopName(searchTargetProfile, searchTargetStop, name)
    }
    searchResults = []
    searchTargetProfile = -1
    searchTargetStop = -1
  }

  Process {
    id: searchProcess
    stdout: StdioCollector {}
    stderr: StdioCollector {}
    onExited: function(exitCode) {
      root.isSearching = false
      var output = String(searchProcess.stdout.text || "").trim()
      if (!output) { root.searchResults = []; return }
      try {
        root.searchResults = JSON.parse(output)
      } catch (e) {
        root.searchResults = []
      }
    }
  }

  spacing: Style.marginM

  NText {
    text: "Bus Tracker"
    font.pointSize: Style.fontSizeXL
    font.bold: true
  }

  NText {
    text: "Dynamic multi-stop bus tracker with profiles, transfers, and notifications"
    color: Color.mSecondary
    Layout.fillWidth: true
    wrapMode: Text.Wrap
  }

  // ── Global Settings ──────────────────────────────

  NDivider { Layout.fillWidth: true; Layout.topMargin: Style.marginM; Layout.bottomMargin: Style.marginM }

  NLabel { label: "Active Hours"; description: "Only poll during these hours" }

  RowLayout {
    Layout.fillWidth: true
    spacing: Style.marginM

    ColumnLayout {
      spacing: 2
      NText { text: "From: " + root.editActiveHoursStart + ":00"; pointSize: Style.fontSizeXS; color: Color.mOnSurfaceVariant }
      NSlider {
        Layout.fillWidth: true
        from: 0; to: 23; stepSize: 1
        value: root.editActiveHoursStart
        onValueChanged: { root.editActiveHoursStart = value; root.saveSettings() }
      }
    }

    ColumnLayout {
      spacing: 2
      NText { text: "To: " + root.editActiveHoursEnd + ":00"; pointSize: Style.fontSizeXS; color: Color.mOnSurfaceVariant }
      NSlider {
        Layout.fillWidth: true
        from: 0; to: 23; stepSize: 1
        value: root.editActiveHoursEnd
        onValueChanged: { root.editActiveHoursEnd = value; root.saveSettings() }
      }
    }
  }

  NLabel {
    label: "Refresh Interval"
    description: "How often to poll (" + root.editRefreshInterval / 1000 + "s)"
  }

  NSlider {
    Layout.fillWidth: true
    from: 10000; to: 120000; stepSize: 5000
    value: root.editRefreshInterval
    onValueChanged: { root.editRefreshInterval = value; root.saveSettings() }
  }

  NLabel {
    label: "Notify Before"
    description: "Alert " + root.editNotifyBeforeMinutes + " minutes before tracked bus arrives"
  }

  NSlider {
    Layout.fillWidth: true
    from: 1; to: 30; stepSize: 1
    value: root.editNotifyBeforeMinutes
    onValueChanged: { root.editNotifyBeforeMinutes = value; root.saveSettings() }
  }

  // ── Profiles ──────────────────────────────

  NDivider { Layout.fillWidth: true; Layout.topMargin: Style.marginM; Layout.bottomMargin: Style.marginM }

  RowLayout {
    Layout.fillWidth: true
    spacing: Style.marginS

    NText {
      text: "Profiles"
      font.pointSize: Style.fontSizeL
      font.bold: true
      Layout.fillWidth: true
    }

    Rectangle {
      implicitWidth: addProfileRow.implicitWidth + Style.marginS * 2
      implicitHeight: addProfileRow.implicitHeight + 4
      radius: Style.radiusS
      color: Qt.alpha(Color.mPrimary, 0.15)

      RowLayout {
        id: addProfileRow
        anchors.centerIn: parent
        spacing: 4

        NIcon { icon: "add"; pointSize: Style.fontSizeS; color: Color.mPrimary }
        NText { text: "Add"; pointSize: Style.fontSizeXS; color: Color.mPrimary; font.weight: Style.fontWeightMedium }
      }

      MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: root.addProfile()
      }
    }
  }

  Repeater {
    model: root.editProfiles

    delegate: ColumnLayout {
      id: profileDelegate
      Layout.fillWidth: true
      spacing: Style.marginS
      Layout.topMargin: Style.marginM

      readonly property int profileIdx: index
      readonly property var profileData: modelData

      // Profile header
      RowLayout {
        Layout.fillWidth: true
        spacing: Style.marginS

        Rectangle {
          implicitWidth: profileIdxText.implicitWidth + Style.marginS * 2
          implicitHeight: profileIdxText.implicitHeight + 4
          radius: Style.radiusS
          color: Qt.alpha(profileDelegate.profileIdx === root.editActiveProfile ? Color.mPrimary : Color.mOnSurfaceVariant, 0.15)

          NText {
            id: profileIdxText
            anchors.centerIn: parent
            text: (profileDelegate.profileIdx + 1).toString()
            pointSize: Style.fontSizeS
            font.weight: Style.fontWeightBold
            color: profileDelegate.profileIdx === root.editActiveProfile ? Color.mPrimary : Color.mOnSurfaceVariant
            font.family: Settings.data.ui.fontFixed
          }

          MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: {
              root.editActiveProfile = profileDelegate.profileIdx
              root.saveSettings()
            }
          }
        }

        NTextInput {
          Layout.fillWidth: true
          label: "Profile Name"
          text: profileDelegate.profileData.name || ""
          onTextChanged: root.updateProfileName(profileDelegate.profileIdx, text)
        }

        Rectangle {
          implicitWidth: 24; implicitHeight: 24
          radius: Style.radiusS
          color: Qt.alpha(Color.mError, 0.15)

          NIcon { anchors.centerIn: parent; icon: "delete"; pointSize: Style.fontSizeXS; color: Color.mError }

          MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: root.removeProfile(profileDelegate.profileIdx)
          }
        }
      }

      // Walk time
      NLabel {
        label: "Walk Time"
        description: (profileDelegate.profileData.walkTime || 5) + " minutes to reach station"
      }

      NSlider {
        Layout.fillWidth: true
        from: 1; to: 30; stepSize: 1
        value: profileDelegate.profileData.walkTime || 5
        onValueChanged: root.updateWalkTime(profileDelegate.profileIdx, value)
      }

      // Stops in this profile
      Repeater {
        model: profileDelegate.profileData.stops || []

        delegate: ColumnLayout {
          id: stopDelegate
          Layout.fillWidth: true
          Layout.leftMargin: Style.marginM
          spacing: Style.marginS
          Layout.topMargin: Style.marginS

          readonly property int stopIdx: index
          readonly property var stopData: modelData

          RowLayout {
            Layout.fillWidth: true
            spacing: Style.marginS

            NText {
              text: "Stop " + (stopDelegate.stopIdx + 1)
              pointSize: Style.fontSizeS
              font.weight: Style.fontWeightBold
              color: Color.mOnSurfaceVariant
            }

            Item { Layout.fillWidth: true }

            Rectangle {
              implicitWidth: 24; implicitHeight: 24
              radius: Style.radiusS
              color: Qt.alpha(Color.mError, 0.15)

              NIcon { anchors.centerIn: parent; icon: "close"; pointSize: Style.fontSizeXS; color: Color.mError }

              MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: root.removeStop(profileDelegate.profileIdx, stopDelegate.stopIdx)
              }
            }
          }

          // Search bar
          RowLayout {
            Layout.fillWidth: true
            spacing: Style.marginS

            NTextInput {
              id: searchInput
              Layout.fillWidth: true
              label: "Search by location"
              placeholderText: "e.g. בני ברק, רחוב הרצל..."
              onAccepted: {
                if (text.trim() !== "") {
                  root.searchStop(text.trim(), profileDelegate.profileIdx, stopDelegate.stopIdx)
                }
              }
            }

            Rectangle {
              implicitWidth: 28; implicitHeight: 28
              radius: Style.radiusS
              color: Qt.alpha(Color.mPrimary, 0.15)

              NIcon {
                anchors.centerIn: parent
                icon: root.isSearching ? "refresh" : "search"
                pointSize: Style.fontSizeS
                color: Color.mPrimary
              }

              MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                  if (searchInput.text.trim() !== "") {
                    root.searchStop(searchInput.text.trim(), profileDelegate.profileIdx, stopDelegate.stopIdx)
                  }
                }
              }
            }
          }

          // Search results
          ColumnLayout {
            Layout.fillWidth: true
            spacing: 2
            visible: root.searchResults.length > 0
                  && root.searchTargetProfile === profileDelegate.profileIdx
                  && root.searchTargetStop === stopDelegate.stopIdx

            Repeater {
              model: (root.searchTargetProfile === profileDelegate.profileIdx
                   && root.searchTargetStop === stopDelegate.stopIdx)
                   ? root.searchResults : []

              delegate: Rectangle {
                Layout.fillWidth: true
                implicitHeight: resultRow.implicitHeight + 8
                radius: Style.radiusS
                color: resultMouse.containsMouse ? Qt.alpha(Color.mPrimary, 0.1) : Qt.alpha(Color.mOnSurface, 0.03)

                readonly property var result: modelData

                RowLayout {
                  id: resultRow
                  anchors.left: parent.left
                  anchors.right: parent.right
                  anchors.verticalCenter: parent.verticalCenter
                  anchors.margins: Style.marginS
                  spacing: Style.marginS

                  NText {
                    text: parent.parent.result.code
                    pointSize: Style.fontSizeXS
                    font.weight: Style.fontWeightBold
                    color: Color.mPrimary
                    font.family: Settings.data.ui.fontFixed
                  }

                  NText {
                    text: parent.parent.result.name
                    pointSize: Style.fontSizeXS
                    color: Color.mOnSurface
                    Layout.fillWidth: true
                    elide: Text.ElideRight
                  }
                }

                MouseArea {
                  id: resultMouse
                  anchors.fill: parent
                  hoverEnabled: true
                  cursorShape: Qt.PointingHandCursor
                  onClicked: root.selectSearchResult(parent.result.code, parent.result.name)
                }
              }
            }
          }

          NTextInput {
            Layout.fillWidth: true
            label: "Stop Code"
            placeholderText: "21477"
            text: stopDelegate.stopData.code || ""
            onTextChanged: root.updateStopCode(profileDelegate.profileIdx, stopDelegate.stopIdx, text)
          }

          NText {
            visible: (stopDelegate.stopData.name || "") !== ""
            text: stopDelegate.stopData.name
            pointSize: Style.fontSizeXS
            color: Color.mOnSurfaceVariant
          }

          NTextInput {
            Layout.fillWidth: true
            label: "Lines (comma-separated, empty = all)"
            placeholderText: "33, 32, 54"
            text: (stopDelegate.stopData.lines || []).join(", ")
            onTextChanged: root.updateStopLines(profileDelegate.profileIdx, stopDelegate.stopIdx, text)
          }
        }
      }

      // Add stop button
      Rectangle {
        Layout.leftMargin: Style.marginM
        implicitWidth: addStopRow.implicitWidth + Style.marginS * 2
        implicitHeight: addStopRow.implicitHeight + 4
        radius: Style.radiusS
        color: Qt.alpha(Color.mTertiary, 0.15)

        RowLayout {
          id: addStopRow
          anchors.centerIn: parent
          spacing: 4

          NIcon { icon: "add"; pointSize: Style.fontSizeXS; color: Color.mTertiary }
          NText { text: "Add Stop"; pointSize: Style.fontSizeXS; color: Color.mTertiary; font.weight: Style.fontWeightMedium }
        }

        MouseArea {
          anchors.fill: parent
          cursorShape: Qt.PointingHandCursor
          onClicked: root.addStop(profileDelegate.profileIdx)
        }
      }

      NDivider { Layout.fillWidth: true; Layout.topMargin: Style.marginS }
    }
  }
}
