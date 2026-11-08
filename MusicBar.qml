import QtQuick
import Quickshell
import Quickshell.Services.Mpris
import qs.Ui
import qs.Commons
import qs.Commons as Commons
import "Model.js" as Model

Panel {
  id: root
  moduleName: "vinyl.player"
  ipcTarget: "vinyl.player"

  readonly property color foreground: bar ? bar.foreground : Commons.Color.foreground
  readonly property string fontFamily: bar ? bar.fontFamily : Style.font.family
  readonly property bool vertical: bar ? bar.vertical : false
  readonly property int barHeight: bar ? bar.barSize : Style.bar.sizeHorizontal
  readonly property real maxLabelWidth: Math.max(Style.space(60), Number(setting("maxLabelWidth", 160)))

  Commons.Translations { id: strings; directory: Qt.resolvedUrl("i18n") }

  readonly property var players: Mpris.players ? Mpris.players.values : []
  readonly property var activePlayer: Model.activePlayer(players, preferredKey)
  readonly property var sourcePlayers: Model.sourcePlayers(players, preferredKey)

  property string preferredKey: ""
  property double now: Date.now()
  property double basePosition: 0
  property double baseStamp: 0

  readonly property bool hasTrack: Model.hasTrack(activePlayer)
  readonly property bool playing: !!activePlayer && !!activePlayer.isPlaying
  readonly property string title: activePlayer ? (activePlayer.trackTitle || strings.t("panel.unknownTrack")) : ""
  readonly property string artist: activePlayer ? (activePlayer.trackArtist || "") : ""
  readonly property string album: activePlayer && activePlayer.trackAlbum ? activePlayer.trackAlbum : ""
  readonly property string artUrl: activePlayer && activePlayer.trackArtUrl ? activePlayer.trackArtUrl : ""
  readonly property string appName: activePlayer ? (activePlayer.identity || activePlayer.desktopEntry || "") : ""
  readonly property real trackLength: activePlayer && activePlayer.lengthSupported && activePlayer.length > 0 ? activePlayer.length : 0
  readonly property bool canSeek: !!activePlayer && !!activePlayer.canSeek && trackLength > 0
  readonly property real position: {
    if (!activePlayer) return 0
    if (!playing) return basePosition
    var next = basePosition + Math.max(0, now - baseStamp) / 1000
    return trackLength > 0 ? Math.min(trackLength, next) : next
  }
  readonly property real shownPosition: seek.dragging ? seek.liveValue : position
  readonly property real artSize: Math.max(Style.space(14), barHeight - Style.space(12))

  function syncPosition() {
    var player = root.activePlayer
    var base = player && player.positionSupported ? Number(player.position) : 0
    root.basePosition = isFinite(base) ? Math.max(0, base) : 0
    root.baseStamp = Date.now()
    root.now = root.baseStamp
  }

  function setPosition(seconds) {
    if (!root.canSeek) return
    var target = Model.clamp(seconds, 0, root.trackLength)
    root.activePlayer.position = target
    root.basePosition = target
    root.baseStamp = Date.now()
    root.now = root.baseStamp
  }

  function seekBy(delta) {
    if (!root.canSeek) return
    root.setPosition(root.shownPosition + delta)
  }

  function togglePlayback() {
    var player = root.activePlayer
    if (!player) return
    if (player.isPlaying && player.canPause) player.pause()
    else if (!player.isPlaying && player.canPlay) player.play()
    else if (player.canTogglePlaying) player.togglePlaying()
    root.preferredKey = Model.playerKey(player)
  }

  function next() {
    var player = root.activePlayer
    if (player && player.canGoNext) player.next()
  }

  function previous() {
    var player = root.activePlayer
    if (player && player.canGoPrevious) player.previous()
  }

  function selectPlayer(key) {
    root.preferredKey = key
    root.syncPosition()
  }

  function samePlayer(a, b) {
    return !!a && !!b && Model.playerKey(a) === Model.playerKey(b)
  }

  function tooltipText() {
    if (!root.hasTrack) return ""
    return root.artist !== "" ? root.title + " · " + root.artist : root.title
  }

  onActivePlayerChanged: root.syncPosition()
  onOpenedChanged: if (opened) root.syncPosition()

  Connections {
    target: root.activePlayer
    function onPositionChanged() { root.syncPosition() }
    function onIsPlayingChanged() { root.syncPosition() }
    function onTrackTitleChanged() { root.syncPosition() }
  }

  Timer {
    interval: 500
    repeat: true
    running: root.opened && root.playing
    onTriggered: root.now = Date.now()
  }





  implicitWidth: root.hasTrack ? barContent.implicitWidth + Style.space(12) : 0
  implicitHeight: root.barHeight
  visible: root.hasTrack

  Item {
    id: barItem
    anchors.fill: parent

    Row {
      id: barContent
      anchors.centerIn: parent
      spacing: Style.space(6)

      Cover {
        id: barCover
        width: root.artSize
        height: root.artSize
        anchors.verticalCenter: parent.verticalCenter
        source: root.artUrl
        glyphSize: Style.font.bodySmall
        fill: Style.normalFillFor(root.foreground, Commons.Color.accent)
      }

      Text {
        id: barGlyph
        textFormat: Text.PlainText
        anchors.verticalCenter: parent.verticalCenter
        text: root.playing ? "󰏤" : "󰐊"
        color: root.playing ? root.foreground : Qt.darker(root.foreground, 1.5)
        font.family: root.fontFamily
        font.pixelSize: Style.font.body
      }

      Item {
        id: labelClip
        visible: !root.vertical
        width: Math.min(root.maxLabelWidth, labelText.implicitWidth)
        height: barGlyph.height
        clip: true
        anchors.verticalCenter: parent.verticalCenter

        Text {
          id: labelText
          textFormat: Text.PlainText
          text: root.artist !== "" ? root.title + "  ·  " + root.artist : root.title
          color: root.foreground
          font.family: root.fontFamily
          font.pixelSize: Style.font.body
          anchors.verticalCenter: parent.verticalCenter

          readonly property bool needsScroll: implicitWidth > labelClip.width

          NumberAnimation on x {
            running: labelText.needsScroll && root.playing && root.visible && !root.opened && !root.vertical && !Style.reduceMotion
            onRunningChanged: if (!running) labelText.x = 0
            loops: Animation.Infinite
            duration: Style.duration(Math.max(6000, labelText.implicitWidth * 25))
            from: labelClip.width
            to: -labelText.implicitWidth
            easing.type: Easing.Linear
          }
        }
      }
    }

    MouseArea {
      anchors.fill: parent
      hoverEnabled: true
      cursorShape: Qt.PointingHandCursor
      acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton

      onClicked: function(mouse) {
        if (mouse.button === Qt.RightButton) root.togglePlayback()
        else if (mouse.button === Qt.MiddleButton) root.next()
        else root.toggle()
      }
      onWheel: function(wheel) {
        if (wheel.angleDelta.y > 0) root.previous()
        else if (wheel.angleDelta.y < 0) root.next()
      }
      onEntered: if (root.bar) root.bar.showTooltip(root, root.tooltipText())
      onExited: if (root.bar) root.bar.hideTooltip(root)
    }
  }

  KeyboardPanel {
    id: panel
    anchorItem: barItem
    owner: root
    bar: root.bar
    open: root.opened
    focusTarget: keyCatcher
    contentWidth: panel.fittedContentWidth(Style.space(360))
    contentHeight: panel.fittedContentHeight(content.implicitHeight, Style.space(540))

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      onCloseRequested: root.close()
      onActivateRequested: root.togglePlayback()
      onMoveRequested: function(dx, dy) {
        if (dx !== 0) root.seekBy(dx * 5)
        else if (dy < 0) root.previous()
        else if (dy > 0) root.next()
      }
      onTextKey: function(text) {
        var key = String(text).toLowerCase()
        if (key === "n") root.next()
        else if (key === "p") root.previous()
        else if (key === " ") root.togglePlayback()
      }

      Column {
        id: content
        width: parent.width
        spacing: Style.space(12)

        Row {
          visible: root.hasTrack
          width: parent.width
          spacing: Style.space(12)

          Cover {
            id: heroCover
            width: Style.space(78)
            height: Style.space(78)
            anchors.verticalCenter: parent.verticalCenter
            source: root.artUrl
            glyphSize: Style.font.displayLarge
            fill: Style.normalFillFor(root.foreground, Commons.Color.accent)
          }

          Column {
            width: parent.width - heroCover.width - Style.space(12)
            spacing: Style.space(3)
            anchors.verticalCenter: parent.verticalCenter

            Text {
              textFormat: Text.PlainText
              width: parent.width
              text: root.title
              color: root.foreground
              font.family: root.fontFamily
              font.pixelSize: Style.font.subtitle
              font.bold: true
              elide: Text.ElideRight
            }

            Text {
              textFormat: Text.PlainText
              width: parent.width
              visible: text !== ""
              text: root.artist
              color: Qt.darker(root.foreground, 1.3)
              font.family: root.fontFamily
              font.pixelSize: Style.font.bodySmall
              elide: Text.ElideRight
            }

            Text {
              textFormat: Text.PlainText
              width: parent.width
              visible: text !== ""
              text: root.album
              color: Qt.darker(root.foreground, 1.6)
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
              elide: Text.ElideRight
            }

            Text {
              textFormat: Text.PlainText
              width: parent.width
              visible: text !== ""
              text: root.appName
              color: Qt.darker(root.foreground, 1.8)
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
              elide: Text.ElideRight
            }
          }
        }

        Column {
          visible: root.hasTrack
          width: parent.width
          spacing: Style.space(2)

          PanelSlider {
            id: seek
            bar: root.bar
            width: parent.width
            minimum: 0
            maximum: Math.max(1, root.trackLength)
            step: 1
            value: root.position
            enabled: root.canSeek
            opacity: root.canSeek ? 1.0 : 0.5

            onReleased: function(value) { root.setPosition(value) }
          }

          Item {
            width: parent.width
            implicitHeight: elapsedText.implicitHeight

            Text {
              id: elapsedText
              textFormat: Text.PlainText
              text: Model.formatTime(root.shownPosition)
              color: Qt.darker(root.foreground, 1.5)
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
              anchors.left: parent.left
            }

            Text {
              textFormat: Text.PlainText
              text: Model.formatTime(root.trackLength)
              color: Qt.darker(root.foreground, 1.5)
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
              anchors.right: parent.right
              visible: root.trackLength > 0
            }
          }
        }

        Row {
          visible: root.hasTrack
          anchors.horizontalCenter: parent.horizontalCenter
          spacing: Style.space(6)
          LayoutMirroring.enabled: false
          LayoutMirroring.childrenInherit: true

          Button {
            iconText: "󰒮"
            foreground: root.foreground
            horizontalPadding: Style.spacing.controlPaddingX
            verticalPadding: Style.spacing.controlPaddingY
            enabled: !!root.activePlayer && root.activePlayer.canGoPrevious
            opacity: enabled ? 1.0 : 0.4
            onClicked: root.previous()
          }

          Button {
            iconText: root.playing ? "󰏤" : "󰐊"
            foreground: root.foreground
            iconSize: Style.font.iconLarge
            horizontalPadding: Style.spacing.panelGap
            verticalPadding: Style.spacing.controlPaddingY
            enabled: !!root.activePlayer && (root.activePlayer.canTogglePlaying || root.activePlayer.canPlay || root.activePlayer.canPause)
            opacity: enabled ? 1.0 : 0.4
            onClicked: root.togglePlayback()
          }

          Button {
            iconText: "󰒭"
            foreground: root.foreground
            horizontalPadding: Style.spacing.controlPaddingX
            verticalPadding: Style.spacing.controlPaddingY
            enabled: !!root.activePlayer && root.activePlayer.canGoNext
            opacity: enabled ? 1.0 : 0.4
            onClicked: root.next()
          }
        }

        Column {
          visible: !root.hasTrack
          width: parent.width
          spacing: Style.space(4)

          Text {
            textFormat: Text.PlainText
            anchors.horizontalCenter: parent.horizontalCenter
            text: "󰝚"
            color: Qt.darker(root.foreground, 1.4)
            font.family: root.fontFamily
            font.pixelSize: Style.font.displayLarge
          }

          Text {
            textFormat: Text.PlainText
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            text: strings.t("panel.nothing")
            color: root.foreground
            font.family: root.fontFamily
            font.pixelSize: Style.font.subtitle
            font.bold: true
          }

          Text {
            textFormat: Text.PlainText
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
            text: strings.t("panel.hint")
            color: Qt.darker(root.foreground, 1.5)
            font.family: root.fontFamily
            font.pixelSize: Style.font.caption
          }
        }

        PanelSeparator {
          visible: root.sourcePlayers.length > 1
          foreground: root.foreground
        }

        Column {
          id: sourceList
          visible: root.sourcePlayers.length > 1
          width: parent.width
          spacing: Style.space(4)

          PanelSectionHeader {
            text: strings.t("panel.players")
            foreground: root.foreground
            fontFamily: root.fontFamily
          }

          Repeater {
            model: root.sourcePlayers

            BorderSurface {
              id: sourceRow
              required property var modelData

              readonly property var player: modelData
              readonly property bool selected: root.samePlayer(root.activePlayer, player)
              readonly property string rowTitle: player ? (player.trackTitle || player.identity || player.desktopEntry || strings.t("panel.unknownTrack")) : ""
              readonly property string rowDetail: player && player.trackArtist ? player.trackArtist : (player ? (player.identity || "") : "")

              width: sourceList.width
              height: sourceInner.implicitHeight + Style.space(10)
              radius: Style.spacing.labelGap
              color: selected ? Style.selectedFillFor(root.foreground, Commons.Color.accent) : "transparent"
              borderSpec: selected ? Border.controlSpec("normal", root.foreground, Commons.Color.accent) : Border.none()

              Row {
                id: sourceInner
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                anchors.leftMargin: sourceRow.borderLeft + Style.space(8)
                anchors.rightMargin: sourceRow.borderRight + Style.space(8)
                spacing: Style.space(8)

                Text {
                  textFormat: Text.PlainText
                  anchors.verticalCenter: parent.verticalCenter
                  text: sourceRow.player && sourceRow.player.isPlaying ? "󰏤" : "󰐊"
                  color: root.foreground
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.body
                  width: Style.space(18)
                  horizontalAlignment: Text.AlignHCenter
                }

                Column {
                  width: parent.width - Style.space(26)
                  spacing: Style.space(1)
                  anchors.verticalCenter: parent.verticalCenter

                  Text {
                    textFormat: Text.PlainText
                    width: parent.width
                    text: sourceRow.rowTitle
                    color: root.foreground
                    font.family: root.fontFamily
                    font.pixelSize: Style.font.bodySmall
                    font.bold: sourceRow.selected
                    elide: Text.ElideRight
                  }

                  Text {
                    textFormat: Text.PlainText
                    width: parent.width
                    visible: text !== ""
                    text: sourceRow.rowDetail
                    color: Qt.darker(root.foreground, 1.5)
                    font.family: root.fontFamily
                    font.pixelSize: Style.font.caption
                    elide: Text.ElideRight
                  }
                }
              }

              MouseArea {
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.selectPlayer(Model.playerKey(sourceRow.player))
              }
            }
          }
        }
      }
    }
  }

  component Cover: BorderSurface {
    id: cover
    property string source: ""
    property real glyphSize: Style.font.icon
    property color fill: Style.normalFillFor(root.foreground, Commons.Color.accent)

    color: cover.fill
    radius: Style.cornerRadius
    borderSpec: Border.none()
    clip: true

    SizedImage {
      anchors.fill: parent
      anchors.margins: Math.max(1, Style.space(1))
      crop: true
      url: cover.source
      visible: cover.source !== ""
    }

    Text {
      textFormat: Text.PlainText
      anchors.centerIn: parent
      visible: cover.source === ""
      text: "󰝚"
      color: root.foreground
      font.family: root.fontFamily
      font.pixelSize: cover.glyphSize
    }
  }
}
