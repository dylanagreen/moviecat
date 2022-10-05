import os
import parsecsv
# import system
import strformat
import strutils

import ranking
import summary_stats



proc letterboxd() =
  let
    # Get the movies from the ranking db so we have their rank
    movies = get_ranked_movies()

    # Get the score bounds for giving everything an /10 score.
    lower_bounds = get_score_bounds()

  var
    # Where to save the exported rankings
    loc = getAppDir() / "letterboxd.csv"
    old_loc = loc

    # Whether this is an update or not
    update = false


  # If the export already exists, we save the information in a new file, then
  # create a seperate file that only includes the updated rankings
  # and then finally move the new file to overwrite the old one.
  if fileExists(loc):
    loc = getAppDir() / "letterboxed_new.csv"
    update = true

  # Gotta put this after the if condition because opening the file
  # will create it if it doesn't exist.
  var
    movie_ids: seq[string] = @[]
    movie_scores: seq[string] = @[]

    # Open the csv file
    f = open(loc, fmWrite)

    # Create an empty file object for the updating file
    f_update: File
  f.writeline("imdbID,Rating10,WatchedDate")

  if update:
    var parser: CSVParser
    parser.open(old_loc)

    # Discarding the existence or not of the very first row
    discard parser.readRow()

    let
      cols = parser.row
      id = cols.find("imdbID")
      rating = cols.find("Rating10")

    # Load the old ids and scores for checking against later
    while parser.readRow():
      movie_ids.add(parser.row[id])
      movie_scores.add(parser.row[rating])

    # Creating the update file
    let update_loc = getAppDir() / "letterboxed_update.csv"
    f_update = open(update_loc, fmWrite)
    f_update.writeline("imdbID,Rating10,WatchedDate")


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

    if update:
      # If the movie doesn't appear in the old rankings at all add it to the
      # update file
      if not(m[0] in movie_ids):
        f_update.writeline(&"{m[0]},{score},{m[2]}")
      else:
        # If the movie does appear check if the score is the same as it was before
        let idx = movie_ids.find(m[0])
        if score != parseInt(movie_scores[idx]):
          f_update.writeline(&"{m[0]},{score},{m[2]}")

      f_update.flushFile()

  # Overwrite the old file with the new one.
  movefile(loc, old_loc)


proc export_csv*(cmd: string) =
  letterboxd()
  return
