import marshal
import os
import streams
import strformat
import strutils

import imdb
import ui_helper

var active_options*: set[keywordType]
let searchable: seq[keywordType] = @[keywordType.year, keywordType.director, keywordType.writer]
let option_names*: array[3, string] = ["year", "director", "writer"]

proc save_options*() =
  # Save the options to a file
  let options_loc = getAppDir() / "options.txt"
  var out_strm = newFileStream(options_loc, fmWrite)
  out_strm.store(active_options)
  out_strm.close()

proc set_option_to_value*(option: string, value: bool) =
  let ind = option_names.find(option)

  # Insert the correct enum value for this option.
  if value: active_options.incl(searchable[ind])
  else: active_options.excl(searchable[ind])

proc set_options*() =
  # Just print lines at first to confirm everything
  echo "Options to edit:"
  for opt in searchable:
    # If the option is active print that it is, otherwise it isn't.
    let val = if opt in active_options: "true" else: "false"
    echo &"{opt}: {val}"
  echo "What would you like to edit?"

  var
    cmd = receive_command()
    to_edit = cmd.toLower()
    active = false

  discard decrypt_answer(cmd) # In case you need to quit at any point.

  if to_edit in option_names:
    echo &"Editing {to_edit}"
    echo "Input true or false to turn this option on or off."

    cmd = receive_command()
    if cmd.toLower() == "cancel": return # In case you changed your mind.
    try:
      active = parseBool(cmd.toLower())
    except ValueError: # Generic Excepts are bad practice
      echo "Invalid boolean value."

    set_option_to_value(to_edit, active)

  # Save the changes
  save_options()