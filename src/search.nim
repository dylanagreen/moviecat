import sequtils
import strformat
import strutils

import imdb
import ui_helper

proc extract_val*(cmd: string, extract: keywordType): tuple[success: bool, val: string] =
  var vals = cmd.split(' ')
  let ind = vals.find($extract)

  # If the keyword is not found, return false
  if ind == -1:
    echo &"{extract} not found."
    return

  if extract == keywordType.year:
    var year = 0
    try:
      year = parseInt(vals[ind + 1])

      # Catch passing negative years.
      if year < 0:
        year = 0
        echo "Invalid year"

    # Index defect when we don't pass a year at all lol.
    except ValueError, IndexDefect:
      echo "Invalid year"

    if year > 0:
      result = (true, $year)

  if extract == keywordType.watched:
    var year = 0
    try:
      year = parseInt(vals[ind + 1])

      # Catch passing negative years.
      if year < 0:
        year = 0
        echo "Invalid year"

    # Index defect when we don't pass a year at all lol.
    except ValueError, IndexDefect:
      echo "Invalid year"

    if year > 0:
      result = (true, $year)

  if extract == keywordType.director:
    var director = ""
    try:
      vals = cmd.split('"')
      let val_contains = map(vals, proc(x: string): bool = x.contains("director"))
      director = vals[val_contains.find(true) + 1]

      # Didn't find a director that you passed so tell the user.
      if director == "": echo "Invalid director. Did you forget quotation marks?"
      else:
        let id = refine_choices(find_person(director), "people")[0]

        if len(id) == 0:
          echo "Director not found!"
        else:
          result = (true, id)

          # Will also trigger if identify person returns an empty container.
    except IndexDefect:
      echo "Invalid director. Did you forget quotation marks?"

  if extract == keywordType.writer:
    var writer = ""
    try:
      vals = cmd.split('"')
      let val_contains = map(vals, proc(x: string): bool = x.contains("writer"))
      writer = vals[val_contains.find(true) + 1]

      # Didn't find a director that you passed so tell the user.
      if writer == "": echo "Invalid writer. Did you forget quotation marks?"
      else:
        let id = refine_choices(find_person(writer), "people")[0]

        if len(id) == 0:
          echo "Writer not found!"
        else:
          result = (true, id)

    # Will also trigger if identify person returns an empty container.
    except IndexDefect:
      echo "Invalid writer. Did you forget quotation marks?"
