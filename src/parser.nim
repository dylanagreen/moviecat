import db_sqlite
import sequtils
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
    director = ""
    vals = cmd.split(' ')

  if cmd.toLower() == "n":
    return

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

  if "director" in vals:
    try:
      vals = cmd.split('"')
      let val_contains = map(vals, proc(x: string): bool = x.contains("director"))
      director = vals[val_contains.find(true) + 1]

      # Didn't find a director that you passed so tell the user.
      if director == "": echo "Invalid director to print. Did you forget quotation marks?"
      else:
        let dirid = refine_choices(find_person(director), "people")[0]

        if len(dirid) == 0:
          echo "Director not found!"
        else:
          result.add("director")
          result.add(dirid)

    # Will also trigger if identify person returns an empty container.
    except IndexDefect:
      echo "Invalid director to print, defaulting to all directors."
      echo "You may have forgot to enclose your director in quotation marks."


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