import db_sqlite
import strformat
import strutils

import csv_export
import help
import imdb
import options
import ranking
import search
import summary_stats
import update
import ui_helper

let
  version = "moviecat v0.5.0dev - Egyptian Mau"
  author = "by Dylan Green"

proc about() =
  echo version
  echo author

proc refine_search(): seq[string] =
  # In this case there are no refine options that are active.
  if active_options.len() == 0:
    return

  echo "Refine search options:"
  var good_options: seq[keywordType]
  for opt in active_options:
    echo &"{opt}"
    good_options.add(opt)

  echo "Input \"N\" to skip."

  var cmd = receive_command()
  if cmd.toLower() == "n":
    return

  # Try and extract each val here.
  for opt in good_options:
    var details = extract_val(cmd, opt)
    if details.success:
      result.add($opt)
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
  elif cmd.toLower().startsWith("help"):
    help_string(cmd)
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
  elif cmd.toLower().startsWith("stats"):
    get_stats(cmd)
  elif cmd.toLower().startsWith("update"):
    update()
  elif cmd.toLower().startsWith("csv") or cmd.toLower().startsWith("export"):
    export_csv(cmd)
  else:
    echo "Unrecognized command"
