import db_sqlite
import marshal
import os
import streams
import strformat
import strutils

import imdb

# Option related enum and set/seq
type SearchOptions* = enum
  BYYEAR

var active_options*: set[SearchOptions]
let option_names*: array[1, string] = ["year"]

# It's fine to duplicate this I think lol.
proc receive_command*(): string =
  result = stdin.readLine

proc shutdown*() =
  # Close the database
  db.close()

  # Save the options to a file
  let options_loc = getAppDir() / "options.txt"
  var out_strm = newFileStream(options_loc, fmWrite)
  out_strm.store(active_options)
  out_strm.close()

  # Quit.
  quit()

# Finds yes or no answers, quits if you want to quit.
proc decrypt_answer*(cmd: string): bool =
  # Always need to be able to quit
  if cmd.toLower() == "quit":
    shutdown()
  elif cmd.toLower() == "yes" or cmd.toLower() == "y":
    return true
  return false


proc set_options*() =
  # Just print lines at first to confirm everything
  echo "Options to edit:"
  for opt in SearchOptions:
    # If the option is active print that it is, otherwise it isn't.
    let val = if opt in active_options: "true" else: "false"
    echo &"{option_names[ord(opt)]}: {val}"
  echo "What would you like to edit?"

  var
    cmd = receive_command()
    to_edit = cmd.toLower()

  discard decrypt_answer(cmd) # In case you need to quit at any point.

  if to_edit in option_names:
    echo &"Editing {to_edit}"
    echo "Input true or false to turn this option on or off."

    cmd = receive_command()
    if cmd.toLower() == "cancel": return # In case you changed your mind.
    try:
      let
        active = parseBool(cmd.toLower())
        ind = option_names.find(to_edit)

      # Insert the correct enum value for this option.
      if active: active_options.incl(SearchOptions(ind))
      else: active_options.excl(SearchOptions(ind))

    except ValueError: # Generic Excepts are bad practice
      echo "Invalid boolean value."