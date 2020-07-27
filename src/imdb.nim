# import logging

import db_sqlite
import os
import parsecsv
import strutils
import strformat
import system


let db* = open("cat.db", "", "", "")
# I keep this line here for testing rebuilding the imdb database from scratch.
# db.exec(sql"DROP TABLE IF EXISTS imdb_db")

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

  while readRow(parser):
    # Skips non movie things, because I don't care about those.
    # Second check ignores movies with no release year.
    if parser.row[1] == "movie" and parser.row[5][0].isDigit:
      # I probably shouldn't hard code this but i'll figure out a way not to later
      db.exec(sql"INSERT INTO imdb_db (id, name, year) VALUES (?, ?, ?)",
              parser.row[0], parser.row[2], parseInt(parser.row[5]))

  # Always want to close when you're done for memory puposes!
  parser.close()

# Looks for the movie you wanted in the imdb database you loaded.
proc find_movie_db*(name: string): seq[Row] =
  # Need to insert the magic % wildcards before and after to search for names
  # that include the search string
  result = db.getAllRows(sql"SELECT * from imdb_db where name LIKE ?", &"%{name}%")
