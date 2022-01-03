import marshal
import os
import streams
import times

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
