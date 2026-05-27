import QtQuick
import qs.Commons

// NixOS snowflake logo — 6 lambda arms from official SVG geometry.
Item {
  id: root

  property real pointSize: Style.fontSizeL
  property bool applyUiScale: true
  property color iconColor: Color.mPrimary

  readonly property real iconSize: Math.max(1, applyUiScale ? root.pointSize * Style.uiScaleRatio : root.pointSize)

  implicitWidth: iconSize
  implicitHeight: iconSize

  Canvas {
    id: canvas
    anchors.fill: parent
    antialiasing: true

    onPaint: {
      var ctx = getContext("2d")
      var s = root.iconSize
      ctx.clearRect(0, 0, s, s)

      var cx = s / 2
      var cy = s / 2
      var sc = s / 100

      // One lambda arm — normalized coordinates from official SVG
      // Center is (0,0), fits in [-50,50] range
      var arm = [
        [-20.2, 1.1],
        [5.1, 44.9],
        [-6.6, 45.0],
        [-13.3, 33.2],
        [-20.1, 44.9],
        [-25.9, 44.9],
        [-28.8, 39.8],
        [-19.1, 23.2],
        [-26.0, 11.2]
      ]

      // 6 rotations: shape1 at 0/60/-60, shape2 at 180/120/-120
      var angles = [0, 60, -60, 180, 120, -120]
      var color1 = root.iconColor
      var color2 = Qt.alpha(root.iconColor, 0.7)

      for (var a = 0; a < angles.length; a++) {
        var angle = angles[a] * Math.PI / 180
        var cos_a = Math.cos(angle)
        var sin_a = Math.sin(angle)

        ctx.beginPath()
        for (var i = 0; i < arm.length; i++) {
          var rx = arm[i][0] * cos_a - arm[i][1] * sin_a
          var ry = arm[i][0] * sin_a + arm[i][1] * cos_a
          var px = cx + rx * sc
          var py = cy + ry * sc
          if (i === 0) ctx.moveTo(px, py)
          else ctx.lineTo(px, py)
        }
        ctx.closePath()
        ctx.fillStyle = (a < 3) ? color1.toString() : color2.toString()
        ctx.fill()
      }
    }

    onWidthChanged: requestPaint()
    onHeightChanged: requestPaint()
  }

  Connections {
    target: root
    function onIconColorChanged() { canvas.requestPaint() }
  }
}
