import strformat
import strutils
import times

import imdb

var
  temp = @[1.0, 2.0, 3.0, 4.0, 5.0, 6.0, 7.0, 8.0, 9.0, 10.0]
  lower = 0
  upper = temp.len - 1
  mid = upper div 2
  ind = -1

echo "Initializing db, please hold a moment..."
var
  t1 = cpuTime()
  db = initialize_movies()
  t2 = cpuTime()
echo &"Initialization complete in {t2 - t1} seconds."
echo &"Loaded {db.movies.len} movies."


proc receive_command*(): string =
  result = stdin.readLine
  # logging.debug("Input: ", result)

proc decrypt_answer(cmd: string): bool =
  # Always need to be able to quit
  if cmd.toLower() == "quit":
    quit()
  elif cmd.toLower() == "yes" or cmd.toLower() == "y":
    return true
  return false


proc auto_insert(val: float) =
  while true:
    var
      ans: bool # The answer to the posed question
      cmd: string

    # These first two if blocks handle edge cases.
    # If the lower and upper bounds are the same we need to check to see if the
    # found position is higher than the value we want to insert.
    # If it is we insert before, if not we insert it after.
    if lower == upper:

      # Find out of the value is better than the lower value, which is the
      # insertion point.
      echo &"Is {val} > {temp[lower]}?"
      cmd = receive_command()
      if cmd != "":
        ans = decrypt_answer(cmd)

      ind = if ans: lower + 1 else: lower
      break

    # If the lower is above the higher bound, then we insert at the lower
    # position, this occurs when we have moved below the bottom of the array.
    if lower > upper:
      ind = lower
      break

    # This is the normal binary search kind of algorithm
    # If the value is above the one at this index, the lower bound is moved above
    # the midpoint, otherwise the upper bound is moved below the midpoint.
    mid = (upper + lower) div 2

     # Find out of the value is better than the midpoint.
    echo &"Is {val} > {temp[mid]}?"
    cmd = receive_command()

    if cmd != "" and decrypt_answer(cmd):
      lower = mid + 1
    else:
      # Normally we might insert at the equality point but here's a secret
      # mega pro tip. If we include code here for inserting at "mid point"
      # it'll get inserted before, the same place as if we just decrease
      # upper and then run the code above where lower > upper and we
      # insert at the same point. Wow! I think. I didn't map it out very
      # robustly.
      upper = mid - 1

  temp.insert(val, ind)

proc find_movie(cmd: string): seq[Movie] =
  let search = cmd.split(' ')
  if search.len < 2:
    echo "Did you forget to pass a movie name to look for?"
    return
  else:
    result = db.find(search[1..^1].join(" "))
    echo "Found these movies:"
    for i in 0..<result.len:
      echo &"[{i}] {result[i]}"

proc insert_movie(cmd: string) =
  let movies = find_movie(cmd)
  var found: Movie
  if movies.len < 1:
    return # Aw sad no movies.
  elif movies.len == 1:
    found = movies[0] # Yay one movie!
  else: # Uh oh lots of movies please tell me which one
    echo "Which movie did you want?"
    var
      i = receive_command()
      bad = true
    while bad:
      try:
        let ind = parseInt(i)
        found = movies[ind]
        bad = false
      except:
        echo "Bad integer passed. Try again."
        i = receive_command()

  echo &"You have selected {found}"


proc decrypt_command*(cmd: string) =
  if cmd.toLower() == "quit":
    quit()
  elif cmd.toLower().startsWith("insert"):
    insert_movie(cmd)
  elif cmd.toLower().startsWith("find"):
    discard find_movie(cmd)
  else:
    echo "Unrecognized command"