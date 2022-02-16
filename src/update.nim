import marshal
import os
import streams
import times

import imdb

let update_loc* = getAppDir() / "update_info.txt"
const UPDATE_CADENCE* = 1

proc write_update_time*() =
  # Literally just checks to see if the file exists, if it does write
  # the now to it, if it doesn't create it then write now to it.
  var out_strm = newFileStream(update_loc, fmWrite)
  out_strm.store(now())
  out_strm.close()

proc should_update*(): bool =
  if not fileExists(update_loc):
    result = true
  else:
    var
      strm = newFileStream(update_loc, fmRead)
      current = now()
      last_update: DateTime
    strm.load(last_update)

    # Update once a week
    if (last_update - current).inWeeks > UPDATE_CADENCE:
      result = true

  if result: echo "Database is over a week old, you should update!"

proc update*(cmd: string) =
  initialize_movies(should_update=true) # Actually initializes the database.

  # Load the directors and writers here.
  # Do the link table first since we only load the people who
  # direct or write, not act.
  initialize_crew(crew="director", should_update=true)
  initialize_crew(crew="writer", should_update=true)
  initialize_people(should_update=true)

  write_update_time()

