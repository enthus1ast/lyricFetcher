# import norm/[model, sqlite]
import prologue
import strtools, strutils, os
import tlyrc
const debug = true
const API_KEY = "123"

let settings = newSettings(appName = "lyrcache", debug = debug)
var app = newApp(
  settings = settings
  # errorHandlerTable=newErrorHandlerTable(),
  # middlewares = middlewares
)

proc genFilename(artist, song: string): string =
  result = artist.delNonAz().toLower() & "_____" & song.delNonAz().toLower() & ".json"

proc genFilename(lyric: Lyric): string =
  genFilename(lyric.artist, lyric.song)

proc store(ctx: Context) {.async.} =
  # We save the stuff even without api key ;)
  var lyric: Lyric
  var js: JsonNode
  try:
    js = parseJson(ctx.request.body)
    lyric = js.to(Lyric)
  except:
    resp("500", Http500)
    return
  let filename = lyric.genFilename()
  if filename.fileExists():
    resp("200", Http200)
    return
  writeFile(getAppDir() / "lyrics" / filename, $js)

  let apiKey = ctx.getPathParams("apiKey", "")
  if apiKey != API_KEY:
    resp("403", Http403)
    return
  else:
    resp("200", Http200)
    return


proc retreive(ctx: Context) {.async.} =
  echo "retreive"
  let artist = ctx.getPathParams("artist", "")
  let song = ctx.getPathParams("song", "")
  let apiKey = ctx.getPathParams("apiKey", "")
  if apiKey != API_KEY: resp("403", Http403)
  else:
    let path = (getAppDir() / "lyrics" / genFilename(artist, song)).replace("..", "")
    if path.fileExists:
      resp readFile(path)
    else:
      resp("404", Http404)

app.addRoute("/get/{artist}/{song}/{apiKey}", retreive, @[HttpGet])
app.addRoute("/push/{apiKey}", store, @[HttpPost])
app.run()