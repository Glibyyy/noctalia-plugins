import QtQuick
import qs.Commons

Item {
  id: root

  property real pointSize: Style.fontSizeL
  property bool applyUiScale: true
  property color iconColor: Color.mPrimary

  readonly property real iconSize: Math.max(1, applyUiScale ? root.pointSize * Style.uiScaleRatio : root.pointSize)

  implicitWidth: iconSize
  implicitHeight: iconSize

  readonly property string _pluginDir: {
    var url = Qt.resolvedUrl(".").toString()
    if (url.startsWith("file://")) url = url.substring(7)
    if (url.endsWith("/")) url = url.substring(0, url.length - 1)
    return url
  }

  Image {
    id: logoImage
    anchors.fill: parent
    source: "file://" + root._pluginDir + "/nixos-logo.svg"
    sourceSize: Qt.size(root.iconSize, root.iconSize)
    fillMode: Image.PreserveAspectFit
    visible: false
  }

  ShaderEffect {
    anchors.fill: parent
    property var source: logoImage
    property color tint: root.iconColor

    fragmentShader: "
      uniform sampler2D source;
      uniform lowp vec4 tint;
      varying highp vec2 qt_TexCoord0;
      void main() {
        lowp vec4 tex = texture2D(source, qt_TexCoord0);
        gl_FragColor = vec4(tint.rgb, tex.a * tint.a);
      }
    "
  }
}
