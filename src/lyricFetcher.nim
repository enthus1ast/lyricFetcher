####################################################################################
# Fetcher
####################################################################################

import asyncdispatch, httpclient, parseutils, json
import strutils
import testdata/testdata
import tlyrc
import strtools
import unidecode
import tables
import options

type
  Fetcher = ref object of RootObj
    fetchUrl: string
    matchUrl: string
  Lyrcache = ref object of Fetcher
  Plyrics = ref object of Fetcher
  Azlyrics = ref object of Fetcher
  Genius = ref object of Fetcher
  Musixmatch = ref object of Fetcher
  SupportedParsers = Table[string, Fetcher]

proc newLyrcache(): Lyrcache =
  result = Lyrcache()
  result.fetchUrl = "http://127.0.0.1:8080/get/$artist/$song/$apikey"
  result.matchUrl = "lyrcache.code0.xyz"

proc newPlyrics(): Plyrics =
  result = Plyrics()
  result.fetchUrl = "http://www.plyrics.com/lyrics/$artist/$song.html"
  result.matchUrl = "plyrics.com"

proc newAzlyrics(): Azlyrics =
  result = Azlyrics()
  result.fetchUrl = "https://www.azlyrics.com/lyrics/$artist/$song.html"
  result.matchUrl = "azlyrics.com"

proc newGenius(): Genius =
  result = Genius()
  result.fetchUrl = "https://genius.com/$artist-$song-lyrics"
  result.matchUrl = "genius.com"

proc newMusixmatch(): Musixmatch =
  result = Musixmatch()
  result.fetchUrl = "https://www.musixmatch.com/de/songtext/$artist/$song"
  result.matchUrl = "musixmatch.com"

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

method fetch(fe: Fetcher, artist, song: string, url: string = ""): Future[Lyric] {.async, base.} =
  raise

method fetch(fe: Lyrcache, artist, song: string, url: string = ""): Future[Lyric] {.async.} =
  # const urlRaw = "http://lyrcache.code0.xyz/get/$artist/$song/$apikey"
  result.url = fe.fetchUrl % [
    "artist", artist.delNonAz().toLower(),
    "song", song.delNonAz().toLower(),
    "apikey", "123"
  ]
  let raw = await get(result.url)
  result = parseJson(raw).to(Lyric)
  echo "CACHE HIT!!!!"

method fetch(fe: Plyrics, artist, song: string, url: string = ""): Future[Lyric] {.async.} =
  if url == "":
    result.url = fe.fetchUrl % [
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

method fetch(fe: Azlyrics, artist, song: string, url: string = ""): Future[Lyric] {.async.} =
  if url == "":
    result.url = fe.fetchUrl % [
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

method fetch(fe: Genius, artist, song: string, url: string = ""): Future[Lyric] {.async.} =
  if url == "":
    result.url = fe.fetchUrl % [
      "artist", artist.delNonAz().toLower().replace("and", "").replace("the", ""),
      "song", song.delNonAz().toLower().replace("and", "").replace("the", "")
    ]
  else:
    result.url = url
  echo result.url
  let raw = await get(result.url)
  result.text = raw.getBetween("""<div class="Lyrics__Container""",  """</div><div class="RightSidebar""").skipStrip("\"").brToNl().cleanHtml()
  result.artist = artist
  result.song = song
  if result.text.strip().len == 0: raise

method fetch(fe: Musixmatch, artist, song: string, url: string = ""): Future[Lyric] {.async.} =
  if url == "":
    result.url = fe.fetchUrl % [
      "artist", artist.delNonAz().toLower().replace("and", "").replace("the", ""), # TODO
      "song", song.delNonAz().toLower().replace("and", "").replace("the", "") # TODO
    ]
  else:
    result.url = url
  echo result.url
  let raw = await get(result.url)
  result.text = raw.getBetween("""<span class="lyrics__content__ok">""",  """<div id="" class="lyrics-report"""").cleanJs().cleanHtml()
  result.artist = artist
  result.song = song
  if result.text.strip().len == 0: raise

proc genSupportedParsers(): SupportedParsers =
  block:
    var fe = newLyrcache()
    result[fe.matchUrl] = fe
  block:
    var fe = newPlyrics()
    result[fe.matchUrl] = fe
  block:
    var fe = newAzlyrics()
    result[fe.matchUrl] = fe
  block:
    var fe = newGenius()
    result[fe.matchUrl] = fe
  block:
    var fe = newMusixmatch()
    result[fe.matchUrl] = fe

####################################################################################
# Searcher
####################################################################################

import htmlparser
import xmltree  # To use '$' for XmlNode
import strtabs  # To access XmlAttributes
import os       # To use splitFile
import strutils # To use cmpIgnoreCase
import uri
import sets
import asyncdispatch
import strformat
import random

randomize()

type
  Searchengine = ref object of RootObj ## The generic search engines, all of them works quite the same
    queryUrl*: string
  SeGeneric = ref object of Searchengine
  SeLycos = ref object of Searchengine
  SeGenius = ref object of Searchengine

proc newSeGoogle(): SeGeneric = result = SeGeneric() ; result.queryUrl = "https://www.google.de/search?q=$query"
proc newSeBing(): SeGeneric = result = SeGeneric() ; result.queryUrl = "https://www.bing.com/search?q=$query"
proc newSeAsk(): SeGeneric = result = SeGeneric() ; result.queryUrl = "https://de.ask.com/web?q=$query"
proc newSeYahoo(): SeGeneric = result = SeGeneric() ; result.queryUrl = "https://de.search.yahoo.com/search?p=$query"
proc newSeExcite(): SeGeneric = result = SeGeneric() ; result.queryUrl = "https://results.excite.com/serp?q=$query"
proc newSeYandex(): SeGeneric = result = SeGeneric() ; result.queryUrl = "https://yandex.ru/search/?text=$query"
proc newSeLycos(): SeLycos = result = SeLycos() ; result.queryUrl = "https://search.lycos.com/web/?q=$query"
# proc newSeAol(): SeAol = result.queryUrl = "https://suche.aol.de/aol/search?q=$query"
# proc newSeDuckDuckGo(): Searchengine = result.queryUrl = "https://duckduckgo.com/?q=$query"
# proc newSeGenius(): SeGenius = result = SeGenius();  result.queryUrl = "https://genius.com/api/search/multi?per_page=5&q=$query"

proc removeWWW(str: string): string =
  if str.startsWith("www."):
    return str[4 .. ^1]
  else:
    return str

proc supportedParser(urlRaw: string, supportedParsers: SupportedParsers): Option[Fetcher] =
  var url = urlRaw
  try:
    if not url.startsWith("http"):
      url = "https://" & url
    let uri = parseUri(url)
    var hostname = uri.hostname.removeWWW()
    if supportedParsers.contains(hostname):
      return some supportedParsers[hostname]
    else:
      return
  except:
    return

method extractSupportedUrls(se: Searchengine, soup: string): seq[string] {.base.} =
  raise

method extractSupportedUrls(se: SeGeneric, soup: string): seq[string] =
  echo "GENERIC"
  var html = parseHtml(soup)
  for aa in findAll(html, "a"):
    if aa.isNil: continue
    if aa.attrsLen == 0: continue
    if aa.attrs.hasKey("href"):
      let href = aa.attr("href")
      # if href.len < 5: continue # filter unrelevant crap
      result.add href

# import json
# method extractSupportedUrls(se: SeGenius, soup: string): seq[string] =
#   echo "SeGenius"
#   # echo soup
#   # let js = soup.parseJson()
#   # for section in js{"response", "sections"}: # [0]["hits"][0]{"result", "path"}
#   #   let hits = section{"hits"}
#   #   if hits.len == 0: continue
#   #   echo hits

method extractSupportedUrls(se: SeLycos, soup: string): seq[string]  =
  echo "Lycos"
  var html = parseHtml(soup)
  for aa in findAll(html, "span"):
    if aa.isNil: continue
    if aa.attrsLen == 0: continue
    if aa.attrs.hasKey("class"):
      if aa.attr("class") != "result-url": continue
      echo aa.innerText
      let href = aa.innerText
      # if href.len < 5: continue # filter unrelevant crap
      result.add href

proc makeQuery(se: Searchengine, artist, song: string): string =
  let query = fmt"{artist} - {song} lyrics"
  result = se.queryUrl % ["query", query.encodeUrl()]

proc findLyricsUrls(artist, song: string): Future[seq[string]] {.async.} =
  var engines: seq[Searchengine]
  engines.add newSeGoogle()
  engines.add newSeBing()
  engines.add newSeAsk()
  engines.add newSeYahoo()
  # engines.add newSeDuckDuckGo()
  engines.add newSeExcite()
  engines.add newSeYandex()
  # engines.add newSeLycos()
  # engines.add newSeGenius()
  engines.shuffle()
  let query = makeQuery(engines[0], artist, song)
  echo query
  let soup = await get(query)
  return extractSupportedUrls(engines[0], soup)


####################################################################################
# Cli
####################################################################################

proc fetchLyrics*(artist, title: string): Future[Lyric] {.async.} =

  # Search for urls
  let urls = await findLyricsUrls(artist, title)
  if urls.len == 0: raise newException(ValueError, fmt"could not find: {artist} - {title} via searchengine")
  var supported = genSupportedParsers()
  for url in urls:
    var opt = url.supportedParser(supported)
    if opt.isNone: continue
    else:
      echo "Parsing from:", opt.get().matchUrl
      echo await fetch(opt.get(), "", "", url = url)
      break
  # try:
  #   echo "FETCH CACHE!!!"
  #   return await fetchLyrcache(artist, title)
  # except:
  #   discard
  #   echo getCurrentExceptionMsg()

  # try:
  #   echo "fetchPlyrics"
  #   return await fetchPlyrics(artist, title)
  # except:
  #   discard

  # try:
  #   echo "fetchAzlyrics"
  #   return await fetchAzlyrics(artist, title)
  # except:
  #   discard

  # try:
  #   echo "fetchGenius"
  #   return await fetchGenius(artist, title)
  # except:
  #   discard

proc cli(artist = "", title = "", apikey = "") =
  try:
    if artist == "" and title == "": raise
    let lyric = waitFor fetchLyrics(artist, title)
    # echo "LYRICS ======================================="
    # echo lyric.text
    # echo "=============================================="
    # if lyric.text.strip().len > 0:
    #   waitFor lyric.pushToLyrcache("123")
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