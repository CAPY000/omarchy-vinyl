function playerKey(player) {
  if (!player) return ""
  return String(player.dbusName || player.identity || "")
}

function isProxy(player) {
  var name = String(player && player.dbusName || "").toLowerCase()
  var entry = String(player && player.desktopEntry || "").toLowerCase()
  return name.indexOf("playerctld") !== -1 || entry === "playerctld"
}

function hasTrack(player) {
  return !!player && !!(player.trackTitle || player.trackArtist)
}

function hasMetadata(player) {
  return !!player && !!(player.trackTitle || player.trackArtist || player.trackAlbum || player.trackArtUrl || player.identity)
}

function labelFor(player) {
  if (!player) return ""
  return player.trackTitle || player.identity || player.desktopEntry || ""
}

function activePlayer(players, preferredKey) {
  var list = players ? players : []
  var preferred = null
  var playing = null
  var resting = null

  for (var i = 0; i < list.length; i++) {
    var player = list[i]
    if (!hasTrack(player)) continue
    if (preferredKey !== "" && playerKey(player) === preferredKey) preferred = player
    if (player.isPlaying && !playing && !isProxy(player)) playing = player
    if (!resting) resting = player
  }

  if (preferred && preferred.isPlaying) return preferred
  if (playing) return playing
  if (preferred) return preferred
  return resting
}

function sourcePlayers(players, preferredKey) {
  var list = []
  for (var i = 0; i < players.length; i++) {
    if (hasMetadata(players[i])) list.push(players[i])
  }

  list.sort(function(a, b) {
    if (!!a.isPlaying !== !!b.isPlaying) return a.isPlaying ? -1 : 1
    if (isProxy(a) !== isProxy(b)) return isProxy(a) ? 1 : -1
    if (playerKey(a) === preferredKey) return -1
    if (playerKey(b) === preferredKey) return 1
    return labelFor(a).localeCompare(labelFor(b))
  })

  return list
}

function clamp(value, minimum, maximum) {
  var number = Number(value)
  if (!isFinite(number)) number = minimum
  return Math.max(minimum, Math.min(maximum, number))
}

function formatTime(seconds) {
  var total = Math.max(0, Math.round(Number(seconds) || 0))
  var rest = total % 60
  var minutes = Math.floor(total / 60) % 60
  var hours = Math.floor(total / 3600)
  var tail = rest < 10 ? "0" + rest : String(rest)
  if (hours > 0) {
    var padded = minutes < 10 ? "0" + minutes : String(minutes)
    return hours + ":" + padded + ":" + tail
  }
  return minutes + ":" + tail
}

if (typeof module !== "undefined") {
  module.exports = {
    playerKey: playerKey,
    isProxy: isProxy,
    hasTrack: hasTrack,
    hasMetadata: hasMetadata,
    labelFor: labelFor,
    activePlayer: activePlayer,
    sourcePlayers: sourcePlayers,
    clamp: clamp,
    formatTime: formatTime
  }
}
