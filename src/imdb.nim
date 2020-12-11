# import logging

import db_sqlite
import os
import parsecsv
import sqlite3
import strutils
import strformat
import system


let db* = open("cat.db", "", "", "")

# I keep this line here for testing rebuilding the imdb database from scratch.
# db.exec(sql"DROP TABLE IF EXISTS imdb_db")
# db.exec(sql"DROP TABLE IF EXISTS ranking")


# I do not overload $ for the Row object because the personal ranking database
# will also return a Row and I do not want to overwrite printing for
# that kind of Row.
proc movie_row_to_string*(movie: Row): string =
  result = &"({movie[0]}) {movie[1]}, {movie[2]}"


proc initialize_movies*(name: string = "title.basics.tsv") =
  # Checks to see if the table already exists and if it does we bail
  if db.getValue(sql"SELECT name FROM sqlite_master WHERE type='table' AND name='imdb_db'") != "":
    echo "IMDB data table detected"
    return

  # For future reference note that format of the tsv is as follows for the header:
  # tconst, movie, primarytitle, originaltitle, isadult, startyear, endyear, runtime, genres
  # Original title is the original language form of the title
  let loc = getAppDir() / name
  # Idiot proofing.
  if not fileExists(loc):
    # logging.error("File not found!")
    # logging.error(&"Attempted to load {name}")
    raise newException(IOError, &"File {loc} not found!")

  # If we got here then the table doesn't exist so we will create it.
  # Gonna throw in a if not exists justtttt in case.
  db.exec(sql"""CREATE TABLE IF NOT EXISTS imdb_db (
                 id   TEXT PRIMARY KEY,
                 name TEXT NOT NULL,
                 year INT
              )""")

  var parser: CSVParser
  parser.open(loc, separator='\t', quote='\0')
  # For future reference so we know file loading succeeded
  # logging.debug(&"Loaded IMDB file: {name}")

  discard parser.readRow()
  let
    cols = parser.row
    id = cols.find("tconst")
    title = cols.find("primaryTitle")
    year = cols.find("startYear")


  var prep = db.prepare("INSERT INTO imdb_db (id, name, year) VALUES (?, ?, ?)")
  db.exec(sql"BEGIN TRANSACTION")

  while parser.readRow():
    # Skips non movie things, because I don't care about those.
    # Second check ignores movies with no release year.
    if parser.row[1] == "movie" and parser.row[year][0].isDigit:
      # Bind parameters to the prepared statement.
      prep.bind_param(1, parser.row[id])
      prep.bind_param(2, parser.row[title])
      prep.bind_param(3, parseInt(parser.row[year]))

      db.exec(prep)
      discard reset(prep.PStmt)

      # db.exec(sql"INSERT INTO imdb_db (id, name, year) VALUES (?, ?, ?)",
      #         parser.row[id], parser.row[title], parseInt(parser.row[year]))

  db.exec(sql"END TRANSACTION")

  # If you don't do this the db will explode when you try do anything.
  prep.finalize()

  # Always want to close when you're done for memory purposes!
  parser.close()

# Looks for the movie you wanted in the imdb database you loaded.
proc find_movie_db*(name: string, params: seq[string]): seq[Row] =
  # Need to insert the magic % wildcards before and after to search for names
  # that include the search string
  var search_string = &"SELECT * FROM imdb_db WHERE name LIKE \'%{name}%\'"

  if params.len > 0:
    if "year" in params:
      let year = params[params.find("year") + 1]
      search_string = search_string & &" AND year={year}"

  result = db.getAllRows(sql(search_string))
