import QtQuick
import qs.Commons

// NixOS snowflake logo drawn with Canvas in theme color.
// Based on the official SVG geometry — one lambda arm replicated 6 times.
Item {
  id: root

  property real pointSize: Style.fontSizeL
  property bool applyUiScale: true
  property color iconColor: Color.mPrimary
  property color iconColorDim: Qt.alpha(iconColor, 0.6)

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
      var scale = s / 100

      // NixOS logo: 6 lambda arms arranged at 60° intervals
      // Each arm is a parallelogram-like shape pointing outward
      // Arms alternate between primary and dimmed color

      function drawArm(ctx, cx, cy, angle, scale, color) {
        ctx.save()
        ctx.translate(cx, cy)
        ctx.rotate(angle * Math.PI / 180)
        ctx.scale(scale, scale)

        // Lambda arm shape — a thick bar with a V-notch
        // Coordinates relative to center, pointing upward
        ctx.beginPath()
        ctx.moveTo(-5.5, -12)   // top-left of bar
        ctx.lineTo(5.5, -12)    // top-right
        ctx.lineTo(22, -40)     // outer-right tip
        ctx.lineTo(11, -40)     // notch right
        ctx.lineTo(0, -21)      // notch bottom (center)
        ctx.lineTo(-11, -40)    // notch left
        ctx.lineTo(-22, -40)    // outer-left tip
        ctx.closePath()

        ctx.fillStyle = color
        ctx.fill()
        ctx.restore()
      }

      // Draw 6 arms at 60° intervals, alternating colors
      for (var i = 0; i < 6; i++) {
        var angle = i * 60
        var color = (i % 2 === 0) ? root.iconColor.toString() : root.iconColorDim.toString()
        drawArm(ctx, cx, cy, angle, scale, color)
      }
    }

    onWidthChanged: requestPaint()
    onHeightChanged: requestPaint()
  }

  Connections {
    target: root
    function onIconColorChanged() { canvas.requestPaint() }
    function onIconColorDimChanged() { canvas.requestPaint() }
  }
}
