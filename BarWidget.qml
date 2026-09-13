import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui

BarWidget {
  id: root
  moduleName: "AppleSiliconThermals"

  property int fanRpm: 0
  property int fanMin: 1199
  property int fanMax: 7199
  property int fanTarget: 0
  property bool fanControlEnabled: false
  property bool manualMode: false
  property real maxTemp: 0
  property real powerWatts: 0
  property var sensors: ({})

  property bool popupOpen: false
  readonly property string helperPath: Qt.resolvedUrl("helper.sh").toString().replace(/^file:\/\//, "")

  function refresh() {
    if (!readProc.running) {
      readProc.running = true
    }
  }

  function togglePopup() {
    popupOpen = !popupOpen
    if (popupOpen) refresh()
  }

  function close() {
    popupOpen = false
  }

  function setSpeed(target) {
    writeProc.targetSpeed = String(target)
    writeProc.running = true
  }

  // Periodic polling for live sensors
  Timer {
    interval: popupOpen ? 1500 : 3000
    running: true
    repeat: true
    triggeredOnStart: true
    onTriggered: root.refresh()
  }

  Process {
    id: readProc
    command: [root.helperPath, "get"]
    stdout: SplitParser {
      onRead: function(line) {
        try {
          var data = JSON.parse(line)
          if (data && !data.error) {
            root.fanRpm = data.fan_rpm || 0
            root.fanMin = data.fan_min || 1199
            root.fanMax = data.fan_max || 7199
            root.fanTarget = data.fan_target || 0
            root.fanControlEnabled = data.fan_control_enabled || false
            root.manualMode = data.manual_mode || false
            root.maxTemp = data.max_temp || 0
            root.powerWatts = data.power_watts || 0
            root.sensors = data.sensors || {}
          }
        } catch (e) {}
      }
    }
  }

  Process {
    id: writeProc
    property string targetSpeed: "auto"
    command: [root.helperPath, "set", targetSpeed]
    onExited: function(code) {
      root.refresh()
    }
  }

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  // Bar icon button with dynamic spinning and thermal status
  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: "󰈐"
    slotSize: Style.bar.statusSlot
    fontSize: Style.font.caption

    // Change foreground color depending on heat or manual mode
    foreground: {
      if (root.maxTemp >= 80) return Color.urgent
      if (root.maxTemp >= 65) return "#ffaa00"
      if (root.manualMode) return Color.accent
      return root.bar ? root.bar.barForeground : Color.foreground
    }

    tooltipText: "Apple Silicon Thermals: " + root.fanRpm + " RPM | " + root.maxTemp + "°C"

    onPressed: function(b) {
      root.togglePopup()
    }

    // Dynamic glyph rotation when fan is active
    NumberAnimation on textRotation {
      from: 0
      to: 360
      duration: Math.max(400, Math.round(60000 / Math.max(root.fanRpm, 600)))
      loops: Animation.Infinite
      running: root.fanRpm > 0
    }
  }

  PopupCard {
    id: popup
    anchorItem: button
    bar: root.bar
    owner: root
    open: root.popupOpen
    contentWidth: popup.fittedContentWidth(Style.space(340))
    contentHeight: popup.fittedContentHeight(mainCol.implicitHeight)

    Column {
      id: mainCol
      anchors.fill: parent
      spacing: Style.space(12)

      // Header row
      Row {
        spacing: Style.space(10)
        width: parent.width

        BorderSurface {
          width: Style.space(36)
          height: Style.space(36)
          radius: Style.spacing.labelGap
          color: Style.normalFillFor(root.bar ? root.bar.foreground : Color.foreground, Color.accent)

          Text {
            anchors.centerIn: parent
            text: "󰈐"
            color: root.manualMode ? Color.accent : (root.bar ? root.bar.foreground : Color.foreground)
            font.family: root.bar ? root.bar.fontFamily : Style.font.family
            font.pixelSize: Style.font.subtitle
          }
        }

        Column {
          anchors.verticalCenter: parent.verticalCenter
          spacing: Style.space(2)

          Text {
            text: "Apple Silicon Thermals"
            color: root.bar ? root.bar.foreground : Color.foreground
            font.family: root.bar ? root.bar.fontFamily : Style.font.family
            font.pixelSize: Style.font.body
            font.bold: true
          }

          Text {
            text: "MacBook Pro (13-inch, M1, 2020)"
            color: Qt.rgba(1, 1, 1, 0.6)
            font.family: root.bar ? root.bar.fontFamily : Style.font.family
            font.pixelSize: Style.font.caption
          }
        }
      }

      PanelSeparator { width: parent.width }

      // Hero Status Card
      BorderSurface {
        width: parent.width
        height: Style.space(64)
        radius: Style.cornerRadius
        color: Style.normalFillFor(root.bar ? root.bar.foreground : Color.foreground, Color.accent)

        Row {
          anchors.fill: parent
          anchors.margins: Style.space(10)

          Column {
            anchors.verticalCenter: parent.verticalCenter
            spacing: Style.space(2)
            width: parent.width * 0.55

            Text {
              text: root.fanRpm > 0 ? (root.fanRpm + " RPM") : "0 RPM (Silencioso)"
              color: root.bar ? root.bar.foreground : Color.foreground
              font.family: root.bar ? root.bar.fontFamily : Style.font.family
              font.pixelSize: Style.font.title
              font.bold: true
            }

            Text {
              text: root.manualMode ? ("Manual (" + root.fanTarget + " RPM)") : "Automático (SMC)"
              color: root.manualMode ? Color.accent : Qt.rgba(1, 1, 1, 0.6)
              font.family: root.bar ? root.bar.fontFamily : Style.font.family
              font.pixelSize: Style.font.caption
            }
          }

          Column {
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width * 0.45
            spacing: Style.space(2)

            Text {
              anchors.right: parent.right
              text: root.maxTemp + "°C"
              color: root.maxTemp >= 75 ? Color.urgent : (root.bar ? root.bar.foreground : Color.foreground)
              font.family: root.bar ? root.bar.fontFamily : Style.font.family
              font.pixelSize: Style.font.title
              font.bold: true
            }

            Text {
              anchors.right: parent.right
              text: root.powerWatts + " W (Potencia)"
              color: Qt.rgba(1, 1, 1, 0.6)
              font.family: root.bar ? root.bar.fontFamily : Style.font.family
              font.pixelSize: Style.font.caption
            }
          }
        }
      }

      // Fan Control Section
      Column {
        width: parent.width
        spacing: Style.space(8)

        // Setup notification if fan_control is not yet active
        BorderSurface {
          width: parent.width
          visible: !root.fanControlEnabled
          radius: Style.cornerRadius
          color: Qt.rgba(1, 0.6, 0, 0.15)
          borderSpec: Border.flat(Color.accent, 1)
          height: Style.space(68)

          Column {
            anchors.fill: parent
            anchors.margins: Style.space(8)
            spacing: Style.space(2)

            Text {
              text: "⚠ Control manual inactivo en kernel"
              color: "#ffbb33"
              font.bold: true
              font.family: root.bar ? root.bar.fontFamily : Style.font.family
              font.pixelSize: Style.font.caption
            }
            Text {
              text: "Ejecuta en tu terminal: sudo " + root.helperPath + " setup"
              color: root.bar ? root.bar.foreground : Color.foreground
              font.family: root.bar ? root.bar.fontFamily : Style.font.family
              font.pixelSize: Style.font.caption
              wrapMode: Text.Wrap
              width: parent.width
            }
          }
        }

        // Manual mode toggle row
        Row {
          width: parent.width
          visible: root.fanControlEnabled
          spacing: Style.space(8)

          Text {
            anchors.verticalCenter: parent.verticalCenter
            text: "Control Manual de Velocidad"
            color: root.bar ? root.bar.foreground : Color.foreground
            font.family: root.bar ? root.bar.fontFamily : Style.font.family
            font.pixelSize: Style.font.body
            width: parent.width - toggleSwitch.width - Style.space(8)
          }

          ToggleSwitch {
            id: toggleSwitch
            anchors.verticalCenter: parent.verticalCenter
            checked: root.manualMode
            onToggled: {
              if (root.manualMode) {
                root.setSpeed("auto")
              } else {
                root.setSpeed(root.fanRpm > 1200 ? root.fanRpm : 2500)
              }
            }
          }
        }

        // Slider for target RPM
        Column {
          width: parent.width
          visible: root.fanControlEnabled && root.manualMode
          spacing: Style.space(4)

          Item {
            width: parent.width
            height: targetLabel.implicitHeight

            Text {
              id: targetLabel
              anchors.left: parent.left
              anchors.verticalCenter: parent.verticalCenter
              text: "Velocidad objetivo:"
              color: Qt.rgba(1, 1, 1, 0.6)
              font.family: root.bar ? root.bar.fontFamily : Style.font.family
              font.pixelSize: Style.font.caption
            }

            Text {
              anchors.right: parent.right
              anchors.verticalCenter: parent.verticalCenter
              text: Math.round(rpmSlider.liveValue) + " RPM"
              color: Color.accent
              font.bold: true
              font.family: root.bar ? root.bar.fontFamily : Style.font.family
              font.pixelSize: Style.font.caption
            }
          }

          PanelSlider {
            id: rpmSlider
            width: parent.width
            bar: root.bar
            minimum: 1200
            maximum: 7200
            step: 100
            integer: true
            value: root.fanTarget >= 1200 ? root.fanTarget : 2500
            onReleased: function(val) {
              root.setSpeed(Math.round(val))
            }
          }
        }

        // Preset Chips
        Row {
          width: parent.width
          visible: root.fanControlEnabled
          spacing: Style.space(6)

          Button {
            text: "Auto"
            width: (parent.width - Style.space(18)) / 4
            selected: !root.manualMode
            onClicked: root.setSpeed("auto")
          }

          Button {
            text: "Quiet"
            width: (parent.width - Style.space(18)) / 4
            selected: root.manualMode && Math.abs(root.fanTarget - 1500) < 300
            onClicked: root.setSpeed(1500)
          }

          Button {
            text: "Medio"
            width: (parent.width - Style.space(18)) / 4
            selected: root.manualMode && Math.abs(root.fanTarget - 3500) < 300
            onClicked: root.setSpeed(3500)
          }

          Button {
            text: "Max"
            width: (parent.width - Style.space(18)) / 4
            selected: root.manualMode && root.fanTarget >= 7000
            onClicked: root.setSpeed(7199)
          }
        }
      }

      PanelSeparator { width: parent.width }

      // Sensor Telemetry List
      Column {
        width: parent.width
        spacing: Style.space(6)

        Text {
          text: "SENSORES DE HARDWARE M1"
          color: Qt.rgba(1, 1, 1, 0.5)
          font.family: root.bar ? root.bar.fontFamily : Style.font.family
          font.pixelSize: Style.font.caption
          font.bold: true
        }

        Grid {
          width: parent.width
          columns: 2
          spacing: Style.space(6)

          Row {
            width: (parent.width - Style.space(6)) / 2
            spacing: Style.space(4)
            Text { text: "NAND Flash:"; color: Qt.rgba(1, 1, 1, 0.6); font.pixelSize: Style.font.caption }
            Text { text: (root.sensors.nand || "--") + "°C"; color: root.bar ? root.bar.foreground : Color.foreground; font.bold: true; font.pixelSize: Style.font.caption }
          }

          Row {
            width: (parent.width - Style.space(6)) / 2
            spacing: Style.space(4)
            Text { text: "Batería:"; color: Qt.rgba(1, 1, 1, 0.6); font.pixelSize: Style.font.caption }
            Text { text: (root.sensors.battery || "--") + "°C"; color: root.bar ? root.bar.foreground : Color.foreground; font.bold: true; font.pixelSize: Style.font.caption }
          }

          Row {
            width: (parent.width - Style.space(6)) / 2
            spacing: Style.space(4)
            Text { text: "Regulador:"; color: Qt.rgba(1, 1, 1, 0.6); font.pixelSize: Style.font.caption }
            Text { text: (root.sensors.regulator || "--") + "°C"; color: root.bar ? root.bar.foreground : Color.foreground; font.bold: true; font.pixelSize: Style.font.caption }
          }

          Row {
            width: (parent.width - Style.space(6)) / 2
            spacing: Style.space(4)
            Text { text: "Wi-Fi / BT:"; color: Qt.rgba(1, 1, 1, 0.6); font.pixelSize: Style.font.caption }
            Text { text: (root.sensors.wifi || "--") + "°C"; color: root.bar ? root.bar.foreground : Color.foreground; font.bold: true; font.pixelSize: Style.font.caption }
          }
        }
      }
    }
  }
}
