import os
# import fusion/
import htmlparser


# import htmlparser
import xmltree  # To use '$' for XmlNode
import strtabs  # To access XmlAttributes
import os       # To use splitFile
import strutils # To use cmpIgnoreCase

import uri
import sets
import asyncdispatch

import strformat


var supported = initHashSet[string]()
supported.incl("genius.com")
supported.incl("azlyrics.com")

type
  Searchengine = ref object of RootObj ## The generic search engines, all of them works quite the same
    queryUrl*: string
  # SeAol = object of Searchengine
  # SeGoogle = object of Searchengine
  # SeBing = object of Searchengine
  # SeAsk = object of Searchengine
  # # SeGenius = object of Searchengine
  # SeYahoo = object of Searchengine
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
# proc newSeGenius(): SeGenius = result.queryUrl = "https://genius.com/search?q=$query"




proc removeWWW(str: string): string =
  if str.startsWith("www."):
    return str[4 .. ^1]
  else:
    return str

proc supportedParser(urlRaw: string): bool =
  var url = urlRaw
  try:
    if not url.startsWith("http"):
      url = "https://" & url
    let uri = parseUri(url)
    var hostname = uri.hostname.removeWWW()
    if supported.contains(hostname):
      return true
    else:
      return false
  except:
    return false

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
      if supportedParser(href):
        result.add href

import json
method extractSupportedUrls(se: SeGenius, soup: string): seq[string] =
  echo "SeGenius"
  # echo soup
  # let js = soup.parseJson()
  # for section in js{"response", "sections"}: # [0]["hits"][0]{"result", "path"}
  #   let hits = section{"hits"}
  #   if hits.len == 0: continue
  #   echo hits

method extractSupportedUrls(se: SeLycos, soup: string): seq[string]  =
  echo "LYCOS"
  var html = parseHtml(soup)
  for aa in findAll(html, "span"):
    if aa.isNil: continue
    if aa.attrsLen == 0: continue
    if aa.attrs.hasKey("class"):
      if aa.attr("class") != "result-url": continue
      echo aa.innerText
      let href = aa.innerText
      if supportedParser(href):
        result.add href


proc makeQuery(se: Searchengine, artist, song: string): string =
  let query = fmt"{artist} - {song} lyrics"
  result = se.queryUrl % ["query", query.encodeUrl()]

# proc findLyricsUrls(se: SeGoogle, artist, song: string): seq[string] =
#   ## googlesearch for the artist and song,
#   ## be careful when doing google searches this way,
#   ## google might block us.
#   ## better try this as last resort.
#   let soup = readFile(getAppDir() / "testdata/ttgooglesearch.txt")
#   return extractSupportedUrls(soup)

# proc findLyricsUrls(se: SeBing, artist, song: string): seq[string] =
#   ## googlesearch for the artist and song,
#   ## be careful when doing google searches this way,
#   ## google might block us.
#   ## better try this as last resort.
#   # https://www.bing.com/search?q=King+Gizzard+%26+The+Lizard+Wizard+-+Murder+Of+The+Universe+-+Altered+Beast+II+lyrics&form=QBLH&sp=-1&pq=&sc=0-0&qs=n&sk=&cvid=D7E288D77FCE44A8A27F2257CDE74BC3
#   let soup = readFile(getAppDir() / "testdata/ttbingsearch.txt")
#   return extractSupportedUrls(soup)

# proc findLyricsUrls(se: SeAsk, artist, song: string): seq[string] =
#   ## googlesearch for the artist and song,
#   ## be careful when doing google searches this way,
#   ## google might block us.
#   ## better try this as last resort.
#   # https://de.ask.com/web?o=0&l=dir&qo=serpSearchTopBox&q=King+Gizzard+%26+The+Lizard+Wizard++-+The+Balrog+lyrics
#   let soup = readFile(getAppDir() / "testdata/ttasksearch.txt")
#   return extractSupportedUrls(soup)

import random
import lyricFetcher

proc findLyricsUrls(artist, song: string): Future[seq[string]] {.async.} =
  # var queries: seq[string]
  # # queries.add makeQuery(newSeGoogle(), artist, song)
  # # queries.add makeQuery(newSeBing(), artist, song)
  # # queries.add makeQuery(newSeAsk(), artist, song)
  # # queries.add makeQuery(newSeYahoo(), artist, song)
  # # queries.add makeQuery(newSeDuckDuckGo(), artist, song)
  # # queries.add makeQuery(newSeExcite(), artist, song)
  # # queries.add makeQuery(newSeYandex(), artist, song)
  # queries.add makeQuery(newSeLycos(), artist, song)
  var engines: seq[Searchengine]
  # queries.add makeQuery(newSeGoogle(), artist, song)
  # queries.add makeQuery(newSeBing(), artist, song)
  # queries.add makeQuery(newSeAsk(), artist, song)
  # queries.add makeQuery(newSeYahoo(), artist, song)
  # queries.add makeQuery(newSeDuckDuckGo(), artist, song)
  # queries.add makeQuery(newSeExcite(), artist, song)
  # queries.add makeQuery(newSeYandex(), artist, song)

  # engines.add newSeGoogle()
  # engines.add newSeLycos()
  engines.add newSeGenius()
  engines.shuffle()
  let query = makeQuery(engines[0], artist, song)
  # echo repr $(engines[0].type)
  echo query
  let soup = await get(query)
  echo soup
  # let soup = ""
  # return extractSupportedUrls(engines[0], soup)


echo waitFor findLyricsUrls("Eminem", "Toy Soldiers")


# when false:
#   var urls =  findLyricsUrls(newSeGoogle(), "kinggz", "venusian")
#   echo urls
#   # echo waitFor fetchGenius("kinggz", "venusian", urls[0])
#   # echo waitFor fetchAzlyrics("kinggz", "venusian", urls[2])

# when false:
#   var urls =  findLyricsUrls(newSeBing(), "kinggz", "venusian")
#   echo urls
#   # echo waitFor fetchGenius("kinggz", "venusian", urls[0])
#   # echo waitFor fetchAzlyrics("kinggz", "venusian", urls[2])

# when true:
#   var urls =  findLyricsUrls(newSeAsk(), "kinggz", "venusian")
#   echo urls
#   # echo waitFor fetchGenius("kinggz", "venusian", urls[0])
#   # echo waitFor fetchAzlyrics("kinggz", "venusian", urls[2])