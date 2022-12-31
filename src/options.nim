import marshal
import os
import streams
import strformat
import strutils

import imdb
import ui_helper
import update

var active_options*: set[keywordType]
let searchable: seq[keywordType] = @[keywordType.year, keywordType.director, keywordType.writer]
let option_names*: array[4, string] = ["year", "director", "writer", "update"]

proc save_options*() =
  # Save the options to a file
  let options_loc = getAppDir() / "options.txt"
  var out_strm = newFileStream(options_loc, fmWrite)
  out_strm.writeLine($$active_options)
  out_strm.writeLine(UPDATE_CADENCE)
  out_strm.close()

proc set_option_to_value*(option: string, value: bool) =
  let ind = option_names.find(option)

  # Insert the correct enum value for this option.
  if value: active_options.incl(searchable[ind])
  else: active_options.excl(searchable[ind])

proc set_options*() =
  # Just print lines at first to confirm everything
  echo "Options to edit:"
  # Prints the search options
  for i, opt in searchable:
    # If the option is active print that it is, otherwise it isn't.
    let val = if opt in active_options: "true" else: "false"
    echo &"[{i}] {opt}: {val}"
  echo &"[{(searchable.len)}] update cadence (weeks): {UPDATE_CADENCE}"
  echo "What (number) would you like to edit?"

  var
    cmd = receive_command()
    bad = true
    active = false
    to_edit = option_names[0]

  discard decrypt_answer(cmd) # In case you need to quit at any point.
  cmd.is_cancel()

  while bad:
    try:
      let ind = parseInt(cmd)
      to_edit = option_names[ind]
      bad = false
    except:
      echo "Bad integer passed. Try again."
      cmd = receive_command()
      discard cmd.decrypt_answer() # In case you pass "quit" and we need to quit.
      cmd.is_cancel()

  echo &"Editing {to_edit}"

  if to_edit != "update":
    echo "Input true or false to turn this option on or off."
  else:
    echo "Input integer value (in weeks) for how often to update the imdb database."

  cmd = receive_command()
  cmd.is_cancel()

  if to_edit != "update":
    try:
      active = parseBool(cmd.toLower())
    except ValueError: # Generic Excepts are bad practice
      echo "Invalid boolean value."

    set_option_to_value(to_edit, active)
  else:
    try:
      UPDATE_CADENCE = parseInt(cmd.toLower())
    except ValueError: # Generic Excepts are bad practice
      echo "Invalid integer value."

  # Save the changes
  save_options()