import os
import strformat
import strutils
import tables

let
  # Command names to load the help files for.
  names = ["about", "help"]

var help_table = initTable[string, string]()
for name in names:
  help_table[name] = readFile(getAppDir()  / "help_pages" / &"{name}.txt")

proc help_string*(cmd: string) =
  let subs = cmd.split(" ")
  var key = "help" # By default show the help string for help command

  if subs.len >= 2:
    key = subs[1]

  echo help_table[key]

  if key == "help":
    echo "Currently implemented commands:"
    echo names.join("\n")




