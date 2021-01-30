import db_sqlite
import strformat
import strutils

import imdb
import options
import ranking
import ui_helper

let
  version = "moviecat v0.1.1 - Calico"
  author = "by Dylan Green"

proc about() =
  echo version
  echo author

proc refine_search(): seq[string] =
  # In this case there are no refine options that are active.
  if active_options.len() == 0:
    return

  echo "Refine search options:"

  for opt in active_options:
    echo &"{option_names[ord(opt)]}"

  echo "Input \"N\" to skip."

  var
    cmd = receive_command()
    year = 0

  if cmd.toLower() == "n":
    return

  let vals = cmd.split(' ')

  # Refining by year. Not the best way to do this just yet, but can be easily
  # refactored later when adding more search refinements.
  if "year" in vals:
    try:
      year = parseInt(vals[vals.find("year") + 1])

      # Catch passing negative years.
      if year < 0:
        year = 0
        echo "Invalid year, ignoring."

    except:
      echo "Invalid year, ignoring."

    if year > 0:
      result.add("year")
      result.add($year)


proc find_movie(cmd: string): Row =
  var movies: seq[Row]
  let search = cmd.split(' ')
  if search.len < 2:
    echo "Did you forget to pass a movie name to look for?"
    return
  else:
    let search_params = refine_search()
    movies = find_movie_db(search[1..^1].join(" "), search_params)
    echo "Found these movies:"
    for i in 0..<movies.len:
      echo &"[{i}] {movie_row_to_string(movies[i])}"

  if movies.len < 1:
    return # Aw sad no movies.
  elif movies.len == 1:
    result = movies[0] # Yay one movie!
  else: # Uh oh lots of movies please tell me which one
    echo "Which movie did you want?"
    var
      i = receive_command()
      bad = true

    discard i.decrypt_answer() # In case you pass "quit" and we need to quit.
    i.is_cancel() # Returns if this is a cancel command.
    while bad:
      try:
        let ind = parseInt(i)
        result = movies[ind]
        bad = false
      except:
        echo "Bad integer passed. Try again."
        i = receive_command()
        discard i.decrypt_answer() # In case you pass "quit" and we need to quit.
        i.is_cancel()

  echo &"You have selected:"
  echo pretty_print_movie(result)


proc insert_movie(cmd: string) =
  let movie = find_movie(cmd)
  if movie.len > 0:
    rank_movie(movie)


proc decrypt_command*(cmd: string) =
  if cmd.toLower() == "quit":
    shutdown()
  elif cmd.toLower().startsWith("insert") or cmd.toLower().startsWith("rank"):
    insert_movie(cmd)
  elif cmd.toLower().startsWith("find"):
    discard find_movie(cmd)
  elif cmd.toLower().startsWith("print"):
    print_rankings(cmd)
  elif cmd.toLower() == "clear":
    clear_rankings()
  elif cmd.toLower() == "options":
    set_options()
  elif cmd.toLower() == "about":
    about()
  else:
    echo "Unrecognized command"