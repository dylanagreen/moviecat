import os
import strutils
import tables

let
  help_table = {"about": readFile(getAppDir()  / "help_pages" / "about.txt"),
                "help": "NAME: help \nUSAGE: help [COMMAND] \nDESCRIPTION: Prints help information about COMMAND."}.toTable

proc help_string*(cmd: string) =
  echo help_table
  let subs = cmd.split(" ")
  var key = "help" # By default show the help string for help command

  if subs.len >= 2:
    key = subs[1]

  echo help_table[key]



