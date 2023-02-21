import os
import strformat
import strutils
import tables

# Compile time load all the help pages.
const help_table = {"about": staticRead("help_pages/about.txt"),
                    "help": staticRead("help_pages/help.txt")}.toTable

proc help_string*(cmd: string) =
  let subs = cmd.split(" ")
  var key = "help" # By default show the help string for help command

  if subs.len >= 2:
    key = subs[1]

  echo help_table[key]

  if key == "help":
    echo "Currently implemented commands:"

    for key in help_table.keys():
      echo key




