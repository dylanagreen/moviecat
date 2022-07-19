import strformat
import strutils

import ranking
import summary_stats

proc letterboxd*() =
  let
    # Get the movies from the ranking db so we have their rank
    movies = get_ranked_movies()

    # Get the score bounds for giving everything an /10 score.
    lower_bounds = get_score_bounds()

  # Open the csv file
  var f = open("letterboxd.csv", fmWrite)
  f.writeline("imdbID,Rating10,WatchedDate")


  for m in movies:
    # I'm not sure if this is faster than the map version (in print_stats_by_keyword)
    # but I think it's faster when you do it 300+ times.
    var score = 0
    let rank = parseInt(m[1])
    while score < lower_bounds.len and lower_bounds[score] <= rank:
      score += 1

    # Remember that above score will return the index of the first *lower* bound
    # that's above m[1], so the real rank of the movie is in the region
    # below.
    score = score - 1

    # Letterboxd doesn't accept 0's so these become 1's.
    # There is one 11/10, representing the best movie in the db (due to a numerical
    # quirk of the way I calculate things). It gets corrected to 10/10 when
    # printing, so should be corrected for letterboxd too.
    if score == 0: score = 1
    elif score == 11: score = 10

    f.writeline(&"{m[0]},{score},{m[2]}")

    # Flush the buffer after every line
    f.flushFile()

  return