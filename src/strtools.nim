import strutils

proc delwhitespace*(str: string): string =
  for ch in str:
    if ch in Whitespace: continue
    else: result.add ch

proc delNonAz*(str: string): string =
  ## King Gizzard & The Lizard Wizard -> KingGizzardTheLizardWizard
  for ch in str:
    if ch notin Letters + Digits: continue
    else: result.add ch

proc getBetween*(str, startTag, endTag: string): string =
  var startIdx = str.find(startTag)
  if startIdx == -1: raise
  startIdx.inc startTag.len

  var endIdx = str.find(endTag, startIdx)
  if endIdx == -1: raise

  if endIdx < startIdx: raise

  return str[startIdx .. endIdx - 1]


proc cleanHtml*(str: string): string =
  var intag = false
  for ch in str:
    if ch == '<':
      intag = true
      continue
    elif ch == '>':
      intag = false
      continue # skip '>'
    if intag: continue
    else: result.add ch

proc brToNl*(str: string): string =
  return str.replace("<br>", "\n").replace("<br/>", "\n")
  # str.multiReplace(
  #   ("<br>", "\n"),
  #   # ("<br>", "\n"),
  # )

proc skipStrip*(str: string, matcher: string): string =
  ## skips to a matcher
  var pos = str.find(matcher)
  pos.inc matcher.len
  return str[pos .. str.len - 1]