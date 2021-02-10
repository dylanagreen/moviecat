import db_sqlite
import sequtils
import strformat
import strutils

import imdb
import options
import ranking
import search
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

  if cmd.toLower() == "n":
    return

  # Try and extract each val here.
  var details = extract_val(cmd, "year")
  if details.success:
    result.add("year")
    result.add(details.val)

  details = extract_val(cmd, "director")
  if details.success:
    result.add("director")
    result.add(details.val)

proc find_movie(cmd: string): Row =
  var movies: seq[Row]
  let search = cmd.split(' ')
  if search.len < 2:
    echo "Did you forget to pass a movie name to look for?"
    return
  else:
    let search_params = refine_search()
    movies = find_movie_db(search[1..^1].join(" "), search_params)

  refine_choices(movies, "movies")


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