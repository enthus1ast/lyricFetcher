# https://www.songtexte.com/search?q=King+Gizzard+%26+The+Lizard+Wizard+Robot+Stop&c=all
# https://www.azlyrics.com/lyrics/kinggizzardthelizardwizard/robotstop.html

# const lyr


import asyncdispatch, httpclient, parseutils, json
import strutils

import testdata/testdata
import tlyrc
import strtools
import unidecode

proc get*(url: string): Future[string] {.async.} =
  var client = newAsyncHttpClient()
  return await client.getContent(url)

proc post*(url: string, data: string) {.async.} =
  var client = newAsyncHttpClient()
  discard await client.postContent(url, body = data)

proc pushToLyrcache(lyric: Lyric, apikey: string) {.async.} =
  # const urlRaw = "http://lyrcache.code0.xyz/push/$apikey"
  const urlRaw = "http://127.0.0.1:8080/push/$apikey"
  let url = urlRaw % ["apikey", apikey]
  let data = $ %* lyric
  await post(url, data)


proc fetchLyrcache(artist, song: string): Future[Lyric] {.async.} =
  # const urlRaw = "http://lyrcache.code0.xyz/get/$artist/$song/$apikey"
  const urlRaw = "http://127.0.0.1:8080/get/$artist/$song/$apikey"
  result.url = urlRaw % [
    "artist", artist.delNonAz().toLower(),
    "song", song.delNonAz().toLower(),
    "apikey", "123"
  ]
  let raw = await get(result.url)
  result = parseJson(raw).to(Lyric)
  echo "CACHE HIT!!!!"

proc fetchPlyrics*(artist, song: string, url = ""): Future[Lyric] {.async.} =
  const urlRaw = "http://www.plyrics.com/lyrics/$artist/$song.html"
  if url == "":
    result.url = urlRaw % [
      "artist", artist.delwhitespace().toLower(),
      "song", song.delwhitespace().toLower()
    ]
  else:
    result.url = url
  let raw = await get(result.url)
  result.text = raw.getBetween("<!-- start of lyrics -->", "<!-- end of lyrics -->").cleanHtml()
  result.artist = artist
  result.song = song
  if result.text.strip().len == 0: raise

proc fetchAzlyrics*(artist, song: string, url = ""): Future[Lyric] {.async.} =
  # https://www.azlyrics.com/lyrics/kinggizzardthelizardwizard/robotstop.html
  const urlRaw = "https://www.azlyrics.com/lyrics/$artist/$song.html"
  if url == "":
    result.url = urlRaw % [
      "artist", artist.unidecode().delNonAz().toLower().replace("and", "").replace("the", ""),
      "song", song.unidecode().delNonAz().toLower().replace("and", "").replace("the", "")
    ]
  else:
    result.url = url
  echo result.url
  let raw = await get(result.url)
  result.text = raw.getBetween("Sorry about that. -->", "<br><br>").cleanHtml()
  result.artist = artist
  result.song = song
  if result.text.strip().len == 0: raise


proc fetchGenius*(artist, song: string, url = ""): Future[Lyric] {.async.} =
  const urlRaw = "https://genius.com/$artist-$song-lyrics"
  if url == "":
    result.url = urlRaw % [
      "artist", artist.delNonAz().toLower().replace("and", "").replace("the", ""),
      "song", song.delNonAz().toLower().replace("and", "").replace("the", "")
    ]
  else:
    result.url = url
  echo result.url
  let raw = await get(result.url)
  # TODO skip crap
  result.text = raw.getBetween("""<div class="Lyrics__Container""",  """</div><div class="RightSidebar""").skipStrip("\"").brToNl().cleanHtml()
  result.artist = artist
  result.song = song
  if result.text.strip().len == 0: raise

  # https://search.azlyrics.com/search.php?q=Kataklysm+Crippled+%26+Broken
  # """1. <a href="""", """">"""




proc fetchLyrics*(artist, title: string): Future[Lyric] {.async.} =
  try:
    echo "FETCH CACHE!!!"
    return await fetchLyrcache(artist, title)
  except:
    discard
    echo getCurrentExceptionMsg()

  try:
    echo "fetchPlyrics"
    return await fetchPlyrics(artist, title)
  except:
    discard

  try:
    echo "fetchAzlyrics"
    return await fetchAzlyrics(artist, title)
  except:
    discard

  try:
    echo "fetchGenius"
    return await fetchGenius(artist, title)
  except:
    discard

proc cli(artist = "", title = "", apikey = "") =
  try:
    if artist == "" and title == "": raise
    let lyric = waitFor fetchLyrics(artist, title)
    echo "LYRICS ======================================="
    echo lyric.text
    echo "=============================================="
    if lyric.text.strip().len > 0:
      waitFor lyric.pushToLyrcache("123")
  except:
    echo "Could not fetch lyrics: ", getCurrentExceptionMsg()

when isMainModule:
  # echo "King Gizzard & The Lizard Wizard".delNonAz()
  import cligen
  dispatch(cli)

  # a
  # echo waitFor fetchPlyrics("Hand Guns", "selfportrait")

  # var cont = """<!-- start lyric -->FOO<!-- end lyric -->"""
  # echo cont.getBetween("<!-- start lyric -->", "<!-- end lyric -->")