import db_sqlite
import strformat
import strutils

import imdb

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


proc identify_person*(people: seq[Row]): Row =
  echo "Found these people:"
  for i in 0..<people.len:
    echo &"[{i}] {person_row_to_string(people[i])}"

  if people.len < 1:
    return # Aw sad no movies.
  elif people.len == 1:
    result = people[0] # Yay one movie!
  else: # Uh oh lots of movies please tell me which one
    echo "Which person did you want?"
    var
      i = receive_command()
      bad = true

    discard i.decrypt_answer() # In case you pass "quit" and we need to quit.
    i.is_cancel() # Returns if this is a cancel command.
    while bad:
      try:
        let ind = parseInt(i)
        result = people[ind]
        bad = false
      except:
        echo "Bad integer passed. Try again."
        i = receive_command()
        discard i.decrypt_answer() # In case you pass "quit" and we need to quit.
        i.is_cancel()

  echo &"You have selected:"
  echo person_row_to_string(result)