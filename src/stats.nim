import db_sqlite
import strformat
import strutils
import tables

import imdb
import ranking

proc get_oldest_newest*(): Table[string, Row] =
  let match_clause = "A.id IN (SELECT id FROM ranking)"

  for s in @["Oldest", "Newest"]:
    # Op for operation
    var op = if s == "Newest": "MAX" else: "MIN"
    let year = db.getValue(sql(&"SELECT {op}(year) FROM imdb_db A WHERE {match_clause}"))

    # This is going to return the first row that complies, and I only store movies
    # by year and not by date, so it will probably always return the alphabetic
    # first movie of the year. This should probably be updated.
    let movie = db.getRow(sql(&"SELECT * FROM imdb_db A WHERE A.year = ? AND {match_clause}"), year)

    result[s] = movie


proc get_best_worst*(): Table[string, Row] =
  for s in @["Worst", "Best"]:
    var op = if s == "Best": "MAX" else: "MIN"

    # Select the id of the movie that has either the max or min ranking value.
    # Remember that this table is stored in reverse, so the minimum (0) is actually
    # the worst ranked movie.
    let id = db.getValue(sql(&"SELECT id from ranking A WHERE A.rank = (SELECT {op}(rank) FROM ranking)"))

    let movie = db.getRow(sql(&"SELECT * FROM imdb_db A WHERE A.id = ? "), id)

    result[s] = movie

proc get_stats*() =
  let num_ranked = db.getValue(sql"SELECT COUNT(ALL) from ranking").parseInt()

  echo &"Number of Movies Ranked: {num_ranked}"

  let oldnew = get_oldest_newest()

  for k, v in oldnew:
    let rank = get_rank(v)[1].parseInt()
    # Don't forget that rank is increasing (higher = better) but the usual
    # expected result is the opposite (lower = better)
    echo &"{k} Movie: [{num_ranked - rank + 1}] {movie_row_to_string(v)}"

  let bestworst = get_best_worst()

  for k, v in bestworst:
    let rank = get_rank(v)[1].parseInt()
    # Don't forget that rank is increasing (higher = better) but the usual
    # expected result is the opposite (lower = better)
    echo &"{k} Ranked Movie: [{num_ranked - rank + 1}] {movie_row_to_string(v)}"

