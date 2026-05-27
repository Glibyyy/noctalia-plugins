import QtQuick
import QtQuick.Shapes
import qs.Commons

// NixOS logo — two overlapping lambdas forming the iconic snowflake shape
Item {
  id: root

  property real pointSize: Style.fontSizeL
  property bool applyUiScale: true
  property color iconColor: Color.mPrimary
  property real dimOpacity: 1.0

  readonly property real iconSize: Math.max(1, applyUiScale ? root.pointSize * Style.uiScaleRatio : root.pointSize)

  implicitWidth: iconSize
  implicitHeight: iconSize

  opacity: root.dimOpacity

  Canvas {
    anchors.fill: parent
    onPaint: {
      var ctx = getContext("2d")
      var s = root.iconSize
      var cx = s / 2
      var cy = s / 2
      var r = s * 0.42

      ctx.clearRect(0, 0, s, s)
      ctx.strokeStyle = root.iconColor.toString()
      ctx.lineWidth = s * 0.12
      ctx.lineCap = "round"

      // Draw 6 arms of the NixOS lambda/snowflake
      for (var i = 0; i < 6; i++) {
        var angle = (i * 60 - 90) * Math.PI / 180
        var x1 = cx + r * 0.25 * Math.cos(angle)
        var y1 = cy + r * 0.25 * Math.sin(angle)
        var x2 = cx + r * Math.cos(angle)
        var y2 = cy + r * Math.sin(angle)

        ctx.beginPath()
        ctx.moveTo(x1, y1)
        ctx.lineTo(x2, y2)
        ctx.stroke()
      }

      // Inner chevrons (lambda shape) — alternating arms get a fork
      for (var j = 0; j < 3; j++) {
        var a1 = (j * 120 - 90) * Math.PI / 180
        var a2 = (j * 120 - 90 + 30) * Math.PI / 180
        var a3 = (j * 120 - 90 - 30) * Math.PI / 180
        var mid = r * 0.55

        var mx = cx + mid * Math.cos(a1)
        var my = cy + mid * Math.sin(a1)
        var fx1 = mx + r * 0.25 * Math.cos(a2)
        var fy1 = my + r * 0.25 * Math.sin(a2)
        var fx2 = mx + r * 0.25 * Math.cos(a3)
        var fy2 = my + r * 0.25 * Math.sin(a3)

        ctx.beginPath()
        ctx.moveTo(fx1, fy1)
        ctx.lineTo(mx, my)
        ctx.lineTo(fx2, fy2)
        ctx.stroke()
      }
    }

    onWidthChanged: requestPaint()
    onHeightChanged: requestPaint()

    Connections {
      target: root
      function onIconColorChanged() { parent.requestPaint() }
    }
  }
}
