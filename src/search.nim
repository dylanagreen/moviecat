import sequtils
import strutils

import imdb
import ui_helper

proc extract_val*(cmd: string, extract: string): tuple[success: bool, val: string] =
  var vals = cmd.split(' ')
  if extract == "year" and "year" in vals:
    var year = 0
    try:
      year = parseInt(vals[vals.find("year") + 1])

      # Catch passing negative years.
      if year < 0:
        year = 0
        echo "Invalid year"

    # Index defect when we don't pass a year at all lol.
    except ValueError, IndexDefect:
      echo "Invalid year"

    if year > 0:
      result = (true, $year)

  if extract == "director" and "director" in vals:
    var director = ""
    try:
      vals = cmd.split('"')
      let val_contains = map(vals, proc(x: string): bool = x.contains("director"))
      director = vals[val_contains.find(true) + 1]

      # Didn't find a director that you passed so tell the user.
      if director == "": echo "Invalid director. Did you forget quotation marks?"
      else:
        let dirid = refine_choices(find_person(director), "people")[0]

        if len(dirid) == 0:
          echo "Director not found!"
        else:
          result = (true, dirid)

          # Will also trigger if identify person returns an empty container.
    except IndexDefect:
      echo "Invalid director. Did you forget quotation marks?"