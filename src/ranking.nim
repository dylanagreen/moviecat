import db_sqlite
import strformat
import strutils
import times

import imdb

# Provided here again to avoid a circular import.
proc receive_command*(): string =
  result = stdin.readLine
  # logging.debug("Input: ", result)


# Insert a movie into its position in the database.
proc decrypt_answer(cmd: string): bool =
  # Always need to be able to quit
  if cmd.toLower() == "quit":
    db.close()
    quit()
  elif cmd.toLower() == "yes" or cmd.toLower() == "y":
    return true
  return false


# Find the movie in the movie db that corresponds to the id in this ranking.
proc ranking_to_string(ranking: Row, watched=false): string =
  let temp = db.getRow(sql"SELECT * FROM imdb_db WHERE id=?", ranking[0])
  result = movie_row_to_string(temp)

  if not ranking[^1].isEmptyOrWhitespace and watched:
    result = result & &" (Watched on {ranking[^1]})"


proc print_rankings*(cmd: string) =
  let vals = cmd.split(' ')
  var rows: seq[Row]

  # Number of movies to print.
  var num = 10
  var year = 0

  if vals.len > 1:
    if "top" in vals:
      try:
        num = parseInt(vals[vals.find("top") + 1])

        # Catch passing in negative numbers.
        if num < 0:
          num = 10
          echo "Invalid number to print, defaulting to top 10."
      except: # Will catch both index out of bounds (no value) or value error
        echo "Invalid number to print, defaulting to top 10."

    if "year" in vals:
      try:
        year = parseInt(vals[vals.find("year") + 1])

        # Catch passing negative years.
        if year < 0:
          year = 0
          echo "Invalid number to print, defaulting to top 10."

      except:
        echo "Invalid year to print, defaulting to all years."

  if year > 0:
    rows = db.getAllRows(sql"SELECT A.* FROM ranking A WHERE A.id in (SELECT B.id FROM imdb_db B WHERE B.year=?) ORDER BY A.rank DESC LIMIT ?", year, num)
    echo &"You have ranked {rows.len} movies from {year}!"
  else:
    rows = db.getAllRows(sql"SELECT * FROM ranking ORDER BY rank DESC LIMIT ?", num)
  if rows.len == 0:
      echo "No rankings to print. Go rank some movies!"

  for i in 0..<rows.len:
    echo &"[{i + 1}] {ranking_to_string(rows[i], true)}"


proc insert_at_rank(movie: Row, rank: int, date = "") =
  # We increase rank by 1 because the binary search is 0 indexed but
  # ranking is 1 indexed. We need to include num_ranked because
  # the insertion algorithm is built such that a higher number is better
  # obviously, but when we rank things on a list, we as humans prefer to
  # but the best at number 1. Hence, needing the total number of ranked movies.
  let num_ranked = parseInt(db.getValue(sql"SELECT COUNT(ALL) from ranking"))
  echo &"Inserting at rank {num_ranked - rank + 1}"

  db.exec(sql"UPDATE ranking SET rank = rank + 1 WHERE rank > ?", rank)

  if date == "":
    db.exec(sql"INSERT INTO ranking (id, rank) VALUES (?, ?)", movie[0], rank + 1)
  else:
    # try:
    db.exec(sql"INSERT INTO ranking (id, rank, date) VALUES (?, ?, ?)", movie[0], rank + 1, date)
  # num_ranked += 1 # Increase the number ranked.


proc delete_movie(id: string) =
  let found = db.getRow(sql"SELECT * FROM ranking WHERE id=?", id)
  let rank = parseInt(found[1])

  # Delete the row, then move all the ones higher ranked down
  db.exec(sql"DELETE FROM ranking WHERE id=?", id)
  db.exec(sql"UPDATE ranking SET rank = rank - 1 WHERE rank > ?", rank)

# Val is the movie you're currently inserting.
# This is the proc that actually does the work.
proc rank_movie*(val: Row) =
  var
    ans: bool # The answer to the posed question
    cmd: string # The input command

    # The movie we're inserting.
    new_movie = movie_row_to_string(val)

    # Whether or not we've already ranked this movie.
    found = db.getRow(sql"SELECT * FROM ranking WHERE id=?", val[0])[0] != ""

  # We must check for found before finding indices since if we overwrite we will
  # delete the movie and move everything ranked higher down, reducing the length
  # by one as well. We must check for this, because id serves as a unique key
  # in the sql database and trying to rank a movie that is already ranked
  # without removing it will cause an exception due to an id clash.
  if found:
    echo &"You have already ranked {new_movie}"
    echo "Would you like to rerank this movie? Note: You will overwrite the old ranking."
    cmd = receive_command()
    ans = decrypt_answer(cmd)

    # If we're overwriting we must delete the old movie and move all ranings down.
    if ans:
      delete_movie(val[0])
    else:
      echo "Overwrite canceled."
      return

  var
    lower = 0
    num_ranked = db.getValue(sql"SELECT COUNT(ALL) from ranking")

    # The indices on the lower and upper bounds for the insertion sort.
    upper = if num_ranked[0].isDigit(): parseInt(num_ranked) - 1 else: 0
    mid = upper div 2
    ind = -1

    # The movie we're comparing to at the midpoint.
    comparison = ranking_to_string(db.getRow(sql"SELECT * FROM ranking WHERE rank=?", mid))

  while true:
    # These first two if blocks handle edge cases.
    # If the lower and upper bounds are the same we need to check to see if the
    # found position is higher than the value we want to insert.
    # If it is we insert before, if not we insert it after.
    if lower == upper:
      # Find out of the value is better than the lower value, which is
      # the insertion point.
      comparison = ranking_to_string(db.getRow(sql"SELECT * FROM ranking WHERE rank=?", lower + 1))
      echo &"Is {new_movie} > {comparison}?"
      cmd = receive_command()
      if cmd != "":
        ans = decrypt_answer(cmd)

      ind = if ans: lower + 1 else: lower
      break

    # If the lower is above the higher bound, then we insert at the lower
    # position, this occurs when we have moved below the bottom of the array.
    if lower > upper:
      ind = lower
      break

    # This is the normal binary search kind of algorithm
    # If the value is above the one at this index, the lower bound is moved above
    # the midpoint, otherwise the upper bound is moved below the midpoint.
    mid = (upper + lower) div 2

     # Find out of the value is better than the midpoint.
     # Increase by one because algo 0 indexed but ranking 1 indexed.
    comparison = ranking_to_string(db.getRow(sql"SELECT * FROM ranking WHERE rank=?", mid + 1))
    echo &"Is {new_movie} > {comparison}?"
    cmd = receive_command()

    if cmd != "" and decrypt_answer(cmd):
      lower = mid + 1
    else:
      # Normally we might insert at the equality point but here's a secret
      # mega pro tip. If we include code here for inserting at "mid point"
      # it'll get inserted before, the same place as if we just decrease
      # upper and then run the code above where lower > upper and we
      # insert at the same point. Wow! I think. I didn't map it out very
      # robustly.
      upper = mid - 1

  echo "What date did you watch this movie? (YYYY-MM-DD)"
  echo "Input \"N\" to skip."
  cmd = receive_command()

  if cmd.toLower() == "n" or cmd.isEmptyOrWhitespace():
    insert_at_rank(val, ind)
  else:
    try:
      let dt = parse(cmd, "yyyy-MM-dd")
      insert_at_rank(val, ind, dt.format("yyyy-MM-dd"))
    except TimeParseError:
      echo "Date not passed in the correct pattern, ignoring."


proc clear_rankings*() =
  echo "Are you sure? This is irreversible."
  let cmd = receive_command()
  if decrypt_answer(cmd):
    db.exec(sql"DELETE FROM ranking")