import algorithm
import db_sqlite
import math
import sequtils
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
    let movie = db.getRow(sql(&"""SELECT * FROM imdb_db A WHERE A.id =
                               (SELECT id from ranking B WHERE B.rank =
                               (SELECT {op}(rank) FROM ranking))"""))

    result[s] = movie


# Returns 10 movies, one "representative" of that score out of ten.
# For this proc we assume that a score between 5-6/10 is average
# So 5 and 6 are each half a st.dev from the mean, 7 and 4 are 1 std dev
# 8 and 3 are 1.5 st dev, 9 and 2 are 2 st.devs from the mean, and
# 10 or 1 is the remainder (>2 st.dev)
proc get_representative(): seq[tuple[score: int, movie: Row]] =
  let
    num_ranked = db.getValue(sql"SELECT COUNT(ALL) from ranking").parseInt()
    half_movies = num_ranked div 2

    # How many movies should be contained within:
    # 1/2 sigma: half
    # 1 sigma: first
    # 3/2 sigma: three_halves
    # 2 sigma: second
    half = int(floor(float(num_ranked) * 0.3829))
    first = int(floor(float(num_ranked) * 0.6827))
    three_halves = int(floor(float(num_ranked) * 0.86638))
    second = int(floor(float(num_ranked) * 0.9545))

  var
    scores = @[1, 2, 3, 4, 5, 6, 7, 8, 9, 10]
    intervals = @[num_ranked, second, three_halves, first, half]

    # Lower bounds for regions below 6/10
    lower_bounds = intervals.map(proc(x: int): int = half_movies - x div 2)
    # Reverse lower is used to find lower bounds > rank 5
    reverse_lower = lower_bounds.reversed()

  # Subtracting the reversed from the max gives us new lower bounds
  reverse_lower = reverse_lower.map(proc(x: int): int = num_ranked - x)
  lower_bounds = concat(lower_bounds, reverse_lower)

  # Insert this at the midpoint to ensure evyerthing is computed correctly
  # as this is the lower bound of the 6/10 ranking and upper of 5/10
  lower_bounds.insert(half_movies, 5)

  # Loop over the out of 10 scores for ordering purposes and then
  # find the midpoint of each range. The midpoint of the range is the
  # "representative movie" for that score out of ten.
  for i, v in scores:
    var val = (lower_bounds[i + 1] - lower_bounds[i]) div 2 + lower_bounds[i]
    let movie = db.getRow(sql"""SELECT * FROM imdb_db A WHERE A.id =
                          (SELECT id from ranking B WHERE B.rank = ?)""", val)

    result.add((v, movie))


proc get_stats*() =
  let num_ranked = db.getValue(sql"SELECT COUNT(ALL) from ranking").parseInt()

  echo &"Number of Movies Ranked: {num_ranked}"

  proc print_stats_table(t: Table[string, Row]) =
    for k, v in t:
      let rank = get_rank(v)[1].parseInt()
      # Don't forget that rank is increasing (higher = better) but the usual
      # expected result is the opposite (lower = better)
      echo &"{k} Ranked Movie: [{num_ranked - rank + 1}] {movie_row_to_string(v)}"

  print_stats_table(get_oldest_newest())
  print_stats_table(get_best_worst())

  # representative score/10 movies.
  echo "\nRepresentative Movies"
  var reps = get_representative()
  for val in reps:
    let rank = get_rank(val.movie)[1].parseInt()
    # Don't forget that rank is increasing (higher = better) but the usual
    # expected result is the opposite (lower = better)
    echo &"{val.score}/10: [{num_ranked - rank + 1}] {movie_row_to_string(val.movie)}"
