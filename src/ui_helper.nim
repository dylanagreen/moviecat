import db_sqlite
import strformat
import strutils

import imdb

type row_to_string* = proc(row: Row): string

# Cancel your current command.
template is_cancel*(cmd: string) =
  if cmd.toLower() == "cancel":
    echo "Cancelled operation."
    return


proc shutdown*() =
  # Close the database
  db.close()
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

# It's fine to duplicate this I think lol.
proc receive_command*(): string =
  result = stdin.readLine


proc refine_choices*(values: seq[Row], dtype: string): Row =
  # Need to use the write print proc depending on what's in the rows.
  var print_proc: row_to_string
  if dtype == "people":
    print_proc = person_row_to_string
  else:
    print_proc = movie_row_to_string

  echo &"Found these {dtype}:"
  for i in 0..<values.len:
    echo &"[{i}] {print_proc(values[i])}"

  if values.len < 1:
    return # Aw sad no movies.
  elif values.len == 1:
    result = values[0] # Yay one movie!
  else: # Uh oh lots of choices please tell me which one
    echo "Which did you want?"
    var
      i = receive_command()
      bad = true

    discard i.decrypt_answer() # In case you pass "quit" and we need to quit.
    i.is_cancel() # Returns if this is a cancel command.
    while bad:
      try:
        let ind = parseInt(i)
        result = values[ind]
        bad = false
      except:
        echo "Bad integer passed. Try again."
        i = receive_command()
        discard i.decrypt_answer() # In case you pass "quit" and we need to quit.
        i.is_cancel()

  echo &"You have selected:"
  echo print_proc(result)