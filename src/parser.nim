import db_sqlite
import strformat
import strutils

import imdb
import ranking

proc receive_command*(): string =
  result = stdin.readLine
  # logging.debug("Input: ", result)

proc find_movie(cmd: string): seq[Row] =
  let search = cmd.split(' ')
  if search.len < 2:
    echo "Did you forget to pass a movie name to look for?"
    return
  else:
    result = find_movie_db(search[1..^1].join(" "))
    echo "Found these movies:"
    for i in 0..<result.len:
      echo &"[{i}] {movie_row_to_string(result[i])}"


proc insert_movie(cmd: string) =
  let movies = find_movie(cmd)
  var found: Row # The movie we decided to insert.
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

  echo &"You have selected {movie_row_to_string(found)}"
  rank_movie(found)


proc decrypt_command*(cmd: string) =
  if cmd.toLower() == "quit":
    db.close()
    quit()
  elif cmd.toLower().startsWith("insert") or cmd.toLower().startsWith("rank"):
    insert_movie(cmd)
  elif cmd.toLower().startsWith("find"):
    discard find_movie(cmd)
  elif cmd.toLower() == "print":
    print_rankings()
  elif cmd.toLower() == "clear":
    clear_rankings()
  else:
    echo "Unrecognized command"