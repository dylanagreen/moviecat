import algorithm
import db_sqlite
import math
import sequtils
import strformat
import strutils
import tables

import imdb
import ranking

proc get_score_bounds(): seq[int] =
  let
    num_ranked = db.getValue(sql"SELECT COUNT(ALL) from ranking").parseInt()
    half_movies = num_ranked div 2

    # How many movies should be contained within:
    # 1/2 sigma: half
    # 1 sigma: first
    # 3/2 sigma: three_halves
    # 2 sigma: second
    # 5/2 sigma: five_halves
    half = int(floor(float(num_ranked) * 0.3829))
    first = int(floor(float(num_ranked) * 0.6827))
    three_halves = int(floor(float(num_ranked) * 0.86638))
    second = int(floor(float(num_ranked) * 0.9545))
    five_halves = int(floor(float(num_ranked) * 0.98758))

    intervals = @[num_ranked, five_halves, second, three_halves, first, half]

    # Lower bounds for regions below 6/10
    lower_bounds = intervals.map(proc(x: int): int = half_movies - x div 2)

  # Reverse lower is used to find lower bounds > rank 5
  var reverse_lower = lower_bounds.reversed()

  # Subtracting the reversed from the max gives us new lower bounds
  reverse_lower = reverse_lower.map(proc(x: int): int = num_ranked - x)
  result = concat(lower_bounds, reverse_lower)


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
    scores = @[0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10]
    lower_bounds = get_score_bounds()

  # Insert this at the midpoint to ensure everything is computed correctly
  # as this is the lower bound of the 6/10 ranking and upper of 5/10
  # lower_bounds.insert(half_movies, 5)

  # Loop over the out of 10 scores for ordering purposes and then
  # find the midpoint of each range. The midpoint of the range is the
  # "representative movie" for that score out of ten.
  for i, v in scores:
    var val = (lower_bounds[i + 1] - lower_bounds[i]) div 2 + lower_bounds[i]
    let movie = db.getRow(sql"""SELECT * FROM imdb_db A WHERE A.id =
                          (SELECT id from ranking B WHERE B.rank = ?)""", val)

    result.add((v, movie))


proc get_all_stats*() =
  let num_ranked = db.getValue(sql"SELECT COUNT(ALL) from ranking").parseInt()

  echo &"Number of Movies Ranked: {num_ranked}"

  proc print_stats_table(t: Table[string, Row]) =
    for k, v in t:
      let rank = get_rank(v)[1].parseInt()
      echo &"{k} Ranked Movie: [{get_overall_rank(rank)}] {movie_row_to_string(v)}"

  print_stats_table(get_oldest_newest())
  print_stats_table(get_best_worst())

  # representative score/10 movies.
  echo "\nRepresentative Movies"
  var reps = get_representative()
  for val in reps:
    let rank = get_rank(val.movie)[1].parseInt()
    echo &"{val.score}/10: [{get_overall_rank(rank)}] {movie_row_to_string(val.movie)}"

proc get_stats*(cmd: string) =
  if cmd.toLower() == "stats":
    get_all_stats()
  else:
    if "movie" in cmd:
      let
        vals = cmd.split(' ')
        ind = vals.find("movie") + 1
        movie_name = vals[ind..^1].join(" ")

        found = get_movie_ranking_db(movie_name)

      # TODO refine search if you've ranked multiple movies with the same name
      if found.len == 0:
        echo &"No movie ranked with name: {movie_name}"
      else:
        let
          found_movie = found[0]

          rank = get_rank(found_movie)

          # Finds the first score interval this fits into and considers that
          # as it's "representative" score, i.e. the score out of 10.
          # Due to <= scores are assigned to the higher interval if they fall
          # right on the boundary.
          lower_bounds = get_score_bounds()
          lower_than_rank = lower_bounds.map(proc(x: int): int = int(x <= rank[1].parseInt()))


        echo &"Stats for {movie_row_to_string(found_movie)}:"
        echo &"Rank: {get_overall_rank(rank[1].parseInt())}"
        echo &"Watched on: {rank[2]}"
        echo &"Representative Score: {lower_than_rank.find(0)}/10"

    elif "year" in cmd:
      let
        vals = cmd.split(' ')
        ind = vals.find("year") + 1

        found_movies = get_ranked_movies_by_year(vals[ind])

        # Need this to find the representitive scores
        lower_bounds = get_score_bounds()

      echo &"Stats for {vals[ind]}:"
      echo &"Number of Movies Watched: {found_movies.len}"

      # Here we will compute the average representitive score by computing
      # each movie's representitive score:
      var reps: seq[int] = @[]

      for i in 0..<found_movies.len:
        let
          temp = found_movies[i]
          lower_than_rank = lower_bounds.map(proc(x: int): int = int(x <= temp[^2].parseInt()))
        reps.add(lower_than_rank.find(0))

      echo &"Highest Ranked: {movie_row_to_string(found_movies[0])} ({reps[0]}/10)"
      echo &"Lowest Ranked: {movie_row_to_string(found_movies[^1])} ({reps[^1]}/10)"

      echo &"Average Representitive Score: {round(reps.sum() / reps.len, 2)/10}"
      # If you ranked less than 10 movies from that year, only display
      # amount of movies you ranked.
      let term = if found_movies.len < 10: found_movies.len else: 10
      echo &"Top {term}:"
      for i in 0..<term:
        let
          temp = found_movies[i]
          overall_rank = get_overall_rank(temp[^2].parseInt())

        var str = movie_row_to_string(temp)
        str &= &" ({reps[i]}/10)"
        # str &= &" (Watched on {temp[^1]})"
        echo &"[{overall_rank}] {str}"
