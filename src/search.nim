import sequtils
import strformat
import strutils

import imdb
import ui_helper

proc extract_val*(cmd: string, extract: keywordType): tuple[success: bool, val: string] =
  var vals = cmd.split(' ')
  let
    ind = vals.find($extract)

    # Find the location for all keywords, so we can find names as being between
    # two keywords
    keywords = @[$keywordType.movie, $keywordType.year, $keywordType.watched,
                  $keywordType.director, $keywordType.writer]
    keyword_locs = keywords.map(proc(x: string): int = vals.find(x))

    extract_idx = keywords.find($extract)

  # If the keyword is not found, return false
  if ind == -1:
    when defined(debug): echo &"{extract} not found."
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

  if extract == keywordType.director or extract == keywordType.writer:
    var print_name = if extract == keywordType.director: "Director" else: "Writer"
    # In this case the keyword is the last one found
    if keyword_locs[extract_idx] == max(keyword_locs):
      # Here is where we need to check that there even is a name....
      if keyword_locs[extract_idx] == len(vals) - 1:
        echo &"{print_name} name not found!"
      else:
        let
          # Join all words after the keyword as the name
          person = vals[(ind + 1)..^1].join(" ")
          found = find_person(person)
          id = refine_choices(found, "people")

        if len(id) == 0:
          echo &"{print_name} not found!"
        else:
          result = (true, id[0])

    else:
      # Need to find the index of the next found keyword, i.e. the first
      # index larger than the current keyword's index
      var next_idx = len(vals) + 1
      for x in keyword_locs:
        if (x < next_idx) and (x > ind):
          next_idx = x

      # In this case there are no words between the two keywords so there
      # is no name to search for!
      if next_idx - extract_idx == 1:
        echo &"{print_name} name not found!"
      else:
        let
          # Join all words after the keyword as the name
          person = vals[(ind + 1)..(next_idx - 1)].join(" ")
          id = refine_choices(find_person(person), "people")[0]

        if len(id) == 0:
          echo &"{print_name} not found!"
        else:
          result = (true, id)
