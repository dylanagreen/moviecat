import db_sqlite
import sequtils
import strformat
import strutils
import times

import imdb
import ui_helper

# Type for the comparison procedure that takes in a
# string and an int and returns a bool
type cmpProc = proc(movie: string, rank: int): bool


# Find the movie in the movie db that corresponds to the id in this ranking.
proc ranking_to_string(ranking: Row, watched=false): string =
  let temp = db.getRow(sql"SELECT * FROM imdb_db WHERE id=?", ranking[0])
  result = movie_row_to_string(temp)

  if not ranking[^1].isEmptyOrWhitespace and watched:
    result = result & &" (Watched on {ranking[^1]})"


proc print_rankings*(cmd: string) =
  var
    vals = cmd.split(' ')
    rows: seq[Row]

    # Number of movies to print.
    num = 10
    year = 0
    director = "" # Order by director
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
    if "year" in vals:
      try:
        year = parseInt(vals[vals.find("year") + 1])

        # Catch passing negative years.
        if year < 0:
          year = 0
          echo "Invalid year to print, defaulting to all years."

      # Index defect when we don't pass a year at all lol.
      except ValueError, IndexDefect:
        echo "Invalid year to print, defaulting to all years."

      if year > 0:
        where_clause &= &" WHERE A.id in (SELECT B.id FROM imdb_db B WHERE B.year={year})"

    if "director" in vals:
      try:
        vals = cmd.split('"')
        let val_contains = map(vals, proc(x: string): bool = x.contains("director"))
        director = vals[val_contains.find(true) + 1]

        # Didn't find a director that you passed so tell the user.
        if director == "": echo "Invalid director to print. Did you forget quotation marks?"
        else:
          let dirid = refine_choices(find_person(director), "people")[0]

          if len(dirid) == 0:
            echo "Director not found!"
          else:
            # For if you're printing year AND director.
            let join = if "WHERE" in where_clause: "AND" else: "WHERE"
            where_clause &= &" {join} A.id in (SELECT B.movie FROM directors B WHERE B.director=\"{dirid}\")"

      # Will also trigger if identify person returns an empty container.
      except IndexDefect:
        echo "Invalid director to print, defaulting to all directors."
        echo "You may have forgot to enclose your director in quotation marks."

  search_string = &"SELECT A.* FROM ranking A{where_clause} ORDER BY rank {order_by} LIMIT ?"
  rows = db.getAllRows(sql(search_string), num)
  for i in 0..<rows.len:
    if order_by == "DESC":
      echo &"[{i + 1}] {ranking_to_string(rows[i], true)}"
    else:
      echo &"[{rows.len - i}] {ranking_to_string(rows[i], true)}"


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
proc get_comparison(movie: string, rank: int): bool =
  let comp = ranking_to_string(db.getRow(sql"SELECT * FROM ranking WHERE rank=?", rank))
  echo &"Is {movie} > {comp}?"
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

  while true:
    # These first two if blocks handle edge cases.
    # If the lower and upper bounds are the same we need to check to see if the
    # found position is higher than the value we want to insert.
    # If it is we insert before, if not we insert it after.
    if lower == upper:
      # Find out of the value is better than the lower value, which is
      # the insertion point.
      greater = comparison(movie, lower + 1)
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
    greater = comparison(movie, mid + 1)
    if greater: lower = mid + 1
    else:
      # Normally we might insert at the equality point but here's a secret
      # mega pro tip. If we include code here for inserting at "mid point"
      # it'll get inserted before, the same place as if we just decrease
      # upper and then run the code above where lower > upper and we
      # insert at the same point. Wow! I think. I didn't map it out very
      # robustly.
      upper = mid - 1


proc rank_movie*(val: Row) =
  var
    ans: bool
    cmd: string # The input command

    # The movie we're inserting.
    new_movie = movie_row_to_string(val)

    # Check to see if we've ranked the movie already by pulling it out of the
    # ranking table. This will return an empty string if we have not
    # rank the movie yet.
    found = db.getRow(sql"SELECT * FROM ranking WHERE id=?", val[0])

  # We must check for found before finding indices since if we overwrite we will
  # delete the movie and move everything ranked higher down, reducing the length
  # by one as well. We must check for this, because id serves as a unique key
  # in the sql database and trying to rank a movie that is already ranked
  # without removing it will cause an exception due to an id clash.
  if found[0] != "":
    echo &"You have already ranked {new_movie} at rank {found[1]}"
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