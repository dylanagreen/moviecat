import db_sqlite
import strformat
import strutils

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
proc ranking_to_string(ranking: Row): string =
  let temp = db.getRow(sql"SELECT * FROM imdb_db WHERE id=?", ranking[0])
  result = movie_row_to_string(temp)

proc insert_at_rank(movie: Row, rank: int) =
  # We increase rank by 7 because the binary search is 0 indexed but
  # ranking is 1 indexed. We need to include num_ranked because
  # the insertion algorithm is built such that a higher number is better
  # obviously, but when we rank things on a list, we as humans prefer to
  # but the best at number 1. Hence, needing the total number of ranked movies.
  let num_ranked = parseInt(db.getValue(sql"SELECT COUNT(ALL) from ranking"))
  echo &"Inserting at rank {num_ranked - rank + 1}"

  db.exec(sql"UPDATE ranking SET rank = rank + 1 WHERE rank > ?", rank)
  db.exec(sql"INSERT INTO ranking (id, rank) VALUES (?, ?)", movie[0], rank + 1)
  # num_ranked += 1 # Increase the number ranked.


# Val is the movie you're currently inserting.
# This is the proc that actually does the work.
proc rank_movie*(val: Row) =
  var
    lower = 0
    num_ranked = db.getValue(sql"SELECT COUNT(ALL) from ranking")
    upper = if num_ranked[0].isDigit(): parseInt(num_ranked) - 1 else: 0
    mid = upper div 2
    ind = -1
    comparison = ranking_to_string(db.getRow(sql"SELECT * FROM ranking WHERE rank=?", mid))
    new_movie = movie_row_to_string(val)

  while true:
    var
      ans: bool # The answer to the posed question
      cmd: string

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

  insert_at_rank(val, ind)

proc print_rankings*() =
  let rows = db.getAllRows(sql"SELECT * FROM ranking ORDER BY rank DESC")

  if rows.len == 0:
    echo "No rankings to print. Go rank some movies!"

  for i in 0..<rows.len:
    echo &"[{i + 1}] {ranking_to_string(rows[i])}"

proc clear_rankings*() =
  echo "Are you sure? This is irreversible."
  let cmd = receive_command()
  if decrypt_answer(cmd):
    db.exec(sql"DELETE FROM ranking")