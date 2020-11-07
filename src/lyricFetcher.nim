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

const userAgent = "Lynx/2.8.6rel.4 libwww-FM/2.14 SSL-MM/1.4.1 OpenSSL/0.9.7l Lynxlet/0.7.0"

type
  Fetcher = ref object of RootObj
    fetchUrl: string
    matchUrl: string
  Lyrcache = ref object of Fetcher
  Plyrics = ref object of Fetcher
  Azlyrics = ref object of Fetcher
  Genius = ref object of Fetcher
  Musixmatch = ref object of Fetcher
  Elyrics = ref object of Fetcher

  SupportedParsers = Table[string, Fetcher]

proc newLyrcache(): Lyrcache =
  result = Lyrcache()
  result.fetchUrl = "http://127.0.0.1:8080/get/$artist/$song/$apikey"
  result.matchUrl = "lyrcache.code0.xyz"

proc newPlyrics(): Plyrics =
  result = Plyrics()
  # result.fetchUrl = "http://www.plyrics.com/lyrics/$artist/$song.html"
  result.matchUrl = "plyrics.com"

proc newAzlyrics(): Azlyrics =
  result = Azlyrics()
  # result.fetchUrl = "https://www.azlyrics.com/lyrics/$artist/$song.html"
  result.matchUrl = "azlyrics.com"

proc newGenius(): Genius =
  result = Genius()
  # result.fetchUrl = "https://genius.com/$artist-$song-lyrics"
  result.matchUrl = "genius.com"

proc newMusixmatch(): Musixmatch =
  result = Musixmatch()
  # result.fetchUrl = "https://www.musixmatch.com/de/songtext/$artist/$song"
  result.matchUrl = "musixmatch.com"

proc newElyrics(): Elyrics =
  result = Elyrics()
  # result.fetchUrl = "https://www.musixmatch.com/de/songtext/$artist/$song"
  result.matchUrl = "elyrics.net"

proc get*(url: string): Future[string] {.async.} =
  var client = newAsyncHttpClient(userAgent = userAgent)
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

method fetch(fe: Plyrics, artist, song: string, url: string): Future[Lyric] {.async.} =
  result.url = url
  result.artist = artist
  result.song = song
  let raw = await get(result.url)
  result.text = raw.getBetween("<!-- start of lyrics -->", "<!-- end of lyrics -->").cleanHtml()
  if result.text.strip().len == 0: raise

method fetch(fe: Azlyrics, artist, song: string, url: string = ""): Future[Lyric] {.async.} =
  result.url = url
  result.artist = artist
  result.song = song
  echo result.url
  let raw = await get(result.url)
  result.text = raw.getBetween("Sorry about that. -->", "<br><br>").cleanHtml()
  if result.text.strip().len == 0: raise

method fetch(fe: Genius, artist, song: string, url: string = ""): Future[Lyric] {.async.} =
  result.url = url
  result.artist = artist
  result.song = song
  echo result.url
  let raw = await get(result.url)
  result.text = raw.getBetween("""<div class="Lyrics__Container""",  """</div><div class="RightSidebar""").skipStrip("\"").brToNl().cleanHtml()
  if result.text.strip().len == 0: raise # newException(ValueError, "cannot find in between from: " & raw)

method fetch(fe: Musixmatch, artist, song: string, url: string = ""): Future[Lyric] {.async.} =
  result.url = url
  result.artist = artist
  result.song = song
  echo result.url
  let raw = await get(result.url)
  result.text = raw.getBetween("""<span class="lyrics__content__ok">""",  """<div id="" class="lyrics-report"""").cleanJs().cleanHtml()
  if result.text.strip().len == 0: raise

method fetch(fe: Elyrics, artist, song: string, url: string = ""): Future[Lyric] {.async.} =
  result.url = url
  result.artist = artist
  result.song = song
  echo result.url
  let raw = await get(result.url)
  result.text = raw.getBetween("""<div id='inlyr'>""",  """</div><br>""").cleanJs().cleanHtml()
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
    var fe = newElyrics()
    result[fe.matchUrl] = fe
  block:
    var fe = newGenius()
    result[fe.matchUrl] = fe
  # block:
  #   var fe = newMusixmatch()
  #   result[fe.matchUrl] = fe

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

proc getSearchEngines(): seq[Searchengine] =
  result = @[]
  result.add newSeGoogle()
  result.add newSeBing()
  result.add newSeAsk()
  result.add newSeYahoo()
  # result.add newSeDuckDuckGo()
  result.add newSeExcite()
  result.add newSeYandex()
  # result.add newSeLycos()
  # result.add newSeGenius()
  result.shuffle()

proc findLyricsUrls(searchengine: Searchengine, artist, song: string): Future[seq[string]] {.async.} =
  let query = makeQuery(searchengine, artist, song)
  echo query
  let soup = await get(query)
  return extractSupportedUrls(searchengine, soup)


####################################################################################
# Cli
####################################################################################

proc fetchLyrics*(artist, title: string): Future[Lyric] {.async.} =

  try:
    echo "FETCH CACHE!!!"
    return await fetch(newLyrcache(), artist, title)
  except:
    discard
    echo getCurrentExceptionMsg()


  var searchengines = getSearchEngines()
  for searchengine in searchengines:

    # Search for urls
    let urls = await findLyricsUrls(searchengine, artist, title)

    var supported = genSupportedParsers()

    var parserUrl: seq[(Fetcher, string)] = @[]
    for url in urls:
      var opt = url.supportedParser(supported)
      if opt.isNone: continue
      parserUrl.add( (opt.get(), url) )

    if parserUrl.len == 0:
      if urls.len == 0:
        echo fmt"could not find: {artist} - {title} via searchengine"
        continue
      # echo "Search engine "

    for (parser, url) in parserUrl:
      try:
        echo "Parsing from:", parser.matchUrl
        return await fetch(parser, artist, title, url = url)
      except:
        echo "Could not get lyrics: " & url
        echo getCurrentExceptionMsg()


proc cli(artist: string, title: string, apikey = "") =
  try:
    # if artist == "" and title == "": raise
    let lyric = waitFor fetchLyrics(artist, title)
    echo "LYRICS ======================================="
    echo lyric.text
    echo "=============================================="
    if lyric.text.strip().len > 0:
      waitFor lyric.pushToLyrcache("123")
  except:
    echo "Could not fetch lyrics: ", getCurrentExceptionMsg()

when isMainModule:
  randomize()
  import cligen
  dispatch(cli)


  # randomize(5)
  # echo waitFor fetch(newElyrics(), "", "", "lyrics...")
  # echo waitFor fetch(newGenius(), "", "", "lyrics...")

  # a
  # echo waitFor fetchPlyrics("Hand Guns", "selfportrait")

  # var cont = """<!-- start lyric -->FOO<!-- end lyric -->"""
  # echo cont.getBetween("<!-- start lyric -->", "<!-- end lyric -->")