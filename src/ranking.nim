import db_sqlite
import math
import strformat
import strutils
import times

import imdb
import search
import ui_helper

# Type for the comparison procedure that takes in a
# string and an int and returns a bool
type cmpProc = proc(movie: string, rank: int, cur_iter: int): bool

# Find the movie in the movie db that corresponds to the id in this ranking.
proc ranking_to_string(ranking: Row, watched=false): string =
  let temp = db.getRow(sql"SELECT * FROM imdb_db WHERE id=?", ranking[0])
  result = movie_row_to_string(temp)

  if not ranking[^1].isEmptyOrWhitespace and watched:
    result = result & &" (Watched on {ranking[^1]})"

proc get_overall_rank*(db_rank: int): int =
  # Don't forget that rank is increasing (higher = better) but the usual
  # expected result is the opposite (lower = better)
  let num_ranked = db.getValue(sql"SELECT COUNT(ALL) from ranking").parseInt()
  result = num_ranked - db_rank + 1

proc print_rankings*(cmd: string) =
  var
    vals = cmd.split(' ')
    rows: seq[Row]

    # Number of movies to print.
    num = 10
    search_string = ""
    order_by = "DESC"
    where_clause = ""

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
    elif "bottom" in vals:
      order_by = "ASC"
      try:
        num = parseInt(vals[vals.find("top") + 1])

        # Catch passing in negative numbers.
        if num < 0:
          num = 10
          echo "Invalid number to print, defaulting to bottom 10."
      except: # Will catch both index out of bounds (no value) or value error
        echo "Invalid number to print, defaulting to bottom 10."

    var details = extract_val(cmd, keywordType.year)
    if details.success:
      where_clause &= &" WHERE A.year={details.val}"

    details = extract_val(cmd, keywordType.watched)
    if details.success:
      # I.e. if you have a WHERE clause, then this needs to be an AND instead
      let join = if "WHERE" in where_clause: "AND" else: "WHERE"
      where_clause &= &" {join} strftime('%Y', B.date) LIKE {details.val}"

    details = extract_val(cmd, keywordType.director)
    if details.success:
      let join = if "WHERE" in where_clause: "AND" else: "WHERE"
      where_clause &= &" {join} A.id in (SELECT C.movie FROM directors C WHERE C.director=\"{details.val}\")"

    details = extract_val(cmd, keywordType.writer)
    if details.success:
      let join = if "WHERE" in where_clause: "AND" else: "WHERE"
      where_clause &= &" {join} A.id in (SELECT C.movie FROM writers C WHERE C.writer=\"{details.val}\")"

  search_string = &"SELECT * FROM imdb_db A INNER JOIN ranking B ON A.id = B.id {where_clause} ORDER BY B.rank {order_by} LIMIT ?"
  var prep = db.prepare(search_string)
  prep.bindParam(1, num)

  rows = db.getAllRows(prep)
  for i in 0..<rows.len:
    var
      temp = rows[i]
      str = movie_row_to_string(temp)

    if not temp[^1].isEmptyOrWhitespace:
      str = str & &" (Watched on {temp[^1]})"

    if order_by == "DESC":
      echo &"[{i + 1}] {str}"
    else:
      echo &"[{rows.len - i}] {str}"

  prep.finalize()


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


# Compares a movie to the movie at rank rank.
# Cur_iter is here for printing purposes
proc get_comparison(movie: string, rank: int, cur_iter: int): bool =
  let comp = ranking_to_string(db.getRow(sql"SELECT * FROM ranking WHERE rank=?", rank))
  echo &"({cur_iter}) Is {movie} > {comp}?"
  let cmd = receive_command()

  # This actually implicitly makes it so that blank strings are taken as "no"
  if cmd != "":
    result = decrypt_answer(cmd)

# Val is the movie you're currently inserting.
# This is the proc that actually does the work.
proc get_movie_rank*(lower_bound, upper_bound: int, movie: string, comparison: cmpProc): int =
  var
    lower = lower_bound
    upper = upper_bound
    mid = (upper + lower) div 2
    greater: bool # Whether A > B

    cur_iter = 1

  while true:
    # These first two if blocks handle edge cases.
    # If the lower and upper bounds are the same we need to check to see if the
    # found position is higher than the value we want to insert.
    # If it is we insert before, if not we insert it after.
    if lower == upper:
      # Find out of the value is better than the lower value, which is
      # the insertion point.
      greater = comparison(movie, lower + 1, cur_iter)
      result = if greater: lower + 1 else: lower
      break

    # If the lower is above the higher bound, then we insert at the lower
    # position, this occurs when we have moved below the bottom of the array.
    if lower > upper:
      result = lower
      break

    # This is the normal binary search kind of algorithm
    # If the value is above the one at this index, the lower bound is moved above
    # the midpoint, otherwise the upper bound is moved below the midpoint.
    mid = (upper + lower) div 2

     # Find out of the value is better than the midpoint.
     # Increase by one because algo 0 indexed but ranking 1 indexed.
    greater = comparison(movie, mid + 1, cur_iter)
    if greater: lower = mid + 1
    else:
      # Normally we might insert at the equality point but here's a secret
      # mega pro tip. If we include code here for inserting at "mid point"
      # it'll get inserted before, the same place as if we just decrease
      # upper and then run the code above where lower > upper and we
      # insert at the same point. Wow! I think. I didn't map it out very
      # robustly.
      upper = mid - 1

    cur_iter += 1


proc get_rank*(movie: Row): Row =
   result = db.getRow(sql"SELECT * FROM ranking WHERE id=?", movie[0])


proc rank_movie*(val: Row) =
  var
    ans: bool
    cmd: string # The input command

    # The movie we're inserting.
    new_movie = movie_row_to_string(val)

    # Check to see if we've ranked the movie already by pulling it out of the
    # ranking table. This will return an empty string if we have not
    # rank the movie yet.
    found = get_rank(val)

    # Need this to display ranks correctly
    num_ranked = db.getValue(sql"SELECT COUNT(ALL) from ranking")

  # We must check for found before finding indices since if we overwrite we will
  # delete the movie and move everything ranked higher down, reducing the length
  # by one as well. We must check for this, because id serves as a unique key
  # in the sql database and trying to rank a movie that is already ranked
  # without removing it will cause an exception due to an id clash.
  if found[0] != "":
    let cur_rank = parseInt(found[1]) - 1

    echo &"You have already ranked {new_movie} at rank {parseInt(num_ranked) - cur_rank}"
    echo "Would you like to rerank this movie? Note: You will overwrite the old ranking."
    cmd = receive_command()
    ans = decrypt_answer(cmd)

    # If we're overwriting we must delete the old movie and move all ratings down.
    if ans:
      delete_movie(val[0])
    else:
      echo "Overwrite canceled."
      return

  var
    lower = 0

    # The indices on the lower and upper bounds for the insertion sort.
    upper = if num_ranked[0].isDigit(): parseInt(num_ranked) - 1 else: 0

  let ind = get_movie_rank(lower, upper, new_movie, get_comparison)

  echo "What date did you watch this movie? (YYYY-MM-DD)"
  echo "Input \"N\" to skip."
  cmd = receive_command()

  # Code block that handles input validation for the dates.
  # In order to sort by date (TODO) we need the date column to be actual
  # SQL compliant dates.
  if cmd.toLower() == "n" or cmd.isEmptyOrWhitespace():
    insert_at_rank(val, ind)
  else:
    try:
      let dt = parse(cmd, "yyyy-MM-dd")
      insert_at_rank(val, ind, dt.format("yyyy-MM-dd"))
    except TimeParseError:
      echo "Date not passed in the correct pattern, ignoring."
      insert_at_rank(val, ind)

proc clear_rankings*() =
  echo "Are you sure? This is irreversible."
  let cmd = receive_command()
  if decrypt_answer(cmd):
    db.exec(sql"DELETE FROM ranking")

# Finds a movie in the ranking db rather than in the imdb database.
proc get_movie_ranking_db*(name: string): seq[Row] =
  # Need to insert the magic % wildcards before and after to search for names
  # that include the search string
  var search_name = name.replace("_", "\\_") # For searching for apostrophes
  search_name = search_name.replace("%", "\\%")

  var
    search_string = "SELECT * FROM imdb_db A WHERE A.name LIKE ? AND A.id in (SELECT B.id FROM ranking B)"
    prep = db.prepare(search_string)

  prep.bindParam(1, &"%{search_name}%")
  result = db.getAllRows(prep)

  # If you don't do this the db will explode when you try do anything.
  prep.finalize()

# Gets all movies ranked in a given year.
proc get_ranked_movies_by_year*(year: string, keyword: keywordType): seq[Row] =
  var
    # Using an inner join to make sure that the returned combined movie results
    # are in ranking order
    clause = if keyword == keywordType.year: "imdb_db.year=?"
             else: "strftime('%Y', ranking.date)=?"
    search_string = &"SELECT * FROM imdb_db INNER JOIN ranking ON imdb_db.id = ranking.id WHERE {clause} ORDER BY ranking.rank DESC"
    prep = db.prepare(search_string)

  prep.bindParam(1, year)
  result = db.getAllRows(prep)

  # If you don't do this the db will explode when you try do anything.
  prep.finalize()

proc get_ranked_movies_by_person*(person: string, role: keywordType): seq[Row] =
  if role != keywordType.director and role != keywordType.writer:
    echo "Invalid role, must be director or writer."
    return

  var
    # Because the keywords are defined as writer/director already this code
    # works as intended by converting the keyword to string which is then
    # inseted, where the strings are the same as both the name of the enum field
    # and the table.
    search_string = &"SELECT * FROM imdb_db A INNER JOIN ranking B ON A.id = B.id WHERE A.id IN (SELECT C.movie FROM {role}s C WHERE C.{role}=?) ORDER BY B.rank DESC"
    prep = db.prepare(search_string)

  prep.bindParam(1, person)
  result = db.getAllRows(prep)

  # If you don't do this the db will explode when you try do anything.
  prep.finalize()


# Returns all ranked movies from the ranking table.
proc get_ranked_movies*(): seq[Row] =
  var
    # Gets everything, orders it by ranking
    search_string = "SELECT * FROM ranking ORDER BY rank DESC"
    prep = db.prepare(search_string)

  result = db.getAllRows(prep)

  # If you don't do this the db will explode when you try do anything.
  prep.finalize()

