# import logging

import db_sqlite
import os
import parsecsv
import sqlite3
import sequtils
import sets
import strutils
import strformat
import system

let db* = open(getAppDir() / "cat.db", "", "", "")

# I keep this line here for testing rebuilding the imdb database from scratch.
# db.exec(sql"DROP TABLE IF EXISTS imdb_db")
# db.exec(sql"DROP TABLE IF EXISTS people")
# db.exec(sql"DROP TABLE IF EXISTS ranking")


# I do not overload $ for the Row object because the personal ranking database
# will also return a Row and I do not want to overwrite printing for
# that kind of Row.
proc movie_row_to_string*(movie: Row): string =
  result = &"({movie[0]}) {movie[1]}, {movie[2]}"

proc person_row_to_string*(person: Row): string =
  result = &"({person[0]}) {person[1]}"


# Prints details in a pretty format instead of a single line string.
proc pretty_print_movie*(movie: Row): string =
  result = &"{movie[1]} ({movie[2]})\n"

  # Getting the director from the relation table
  let director = db.getAllRows(sql"SELECT director FROM directors WHERE movie=?", movie[0])
  var name = ""
  # echo direct_names
  if director.len > 1:
    for i, d in director:
      name &= db.getRow(sql"SELECT name FROM people WHERE id=?", d)[0]

      if i < (director.len - 1):
        name &= ", "
  else:
    name = db.getRow(sql"SELECT name FROM people WHERE id=?", director[0])[0]

  result &= &"Director: {name}\n"


proc initialize_people*(name: string = "name.basics.tsv") =
  # Checks to see if the table already exists and if it does we bail
  if db.getValue(sql"SELECT name FROM sqlite_master WHERE type='table' AND name='people'") != "":
    echo "People table detected"
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
  db.exec(sql"""CREATE TABLE IF NOT EXISTS people (
                 id   TEXT PRIMARY KEY,
                 name TEXT NOT NULL
              )""")

  var parser: CSVParser
  parser.open(loc, separator='\t', quote='\0')
  # For future reference so we know file loading succeeded
  # logging.debug(&"Loaded IMDB file: {name}")

  let directors = map(db.getAllRows(sql"SELECT director FROM directors"), proc(x: Row): string = x[0]).toHashSet

  # Discarding the true or false row exists boolean
  discard parser.readRow()
  let
    cols = parser.row
    id = cols.find("nconst")
    title = cols.find("primaryName")


  var prep = db.prepare("INSERT INTO people (id, name) VALUES (?, ?)")
  db.exec(sql"BEGIN TRANSACTION")

  while parser.readRow():
    # Skip people who didn't direct a movie.
    if not(parser.row[id] in directors): continue
    # Bind parameters to the prepared statement.
    prep.bind_param(1, parser.row[id])
    prep.bind_param(2, parser.row[title])

    db.exec(prep)
    discard reset(prep.PStmt)

  db.exec(sql"END TRANSACTION")

  # If you don't do this the db will explode when you try do anything.
  prep.finalize()

  # Always want to close when you're done for memory purposes!
  parser.close()


proc initialize_directors*(name: string = "title.crew.tsv") =
  # Checks to see if the table already exists and if it does we bail
  if db.getValue(sql"SELECT name FROM sqlite_master WHERE type='table' AND name='directors'") != "":
    echo "Directors table detected"
    return

  let loc = getAppDir() / name
  # Idiot proofing.
  if not fileExists(loc):
    # logging.error("File not found!")
    # logging.error(&"Attempted to load {name}")
    raise newException(IOError, &"File {loc} not found!")

  # Now make the directors table.
  # We use a movie/director combination as a primary key, which ensures
  # that each relation is unique, but allows multiple instances of
  # movies and directors (useful since a director could direct more than one
  # movie and a movie could have more than one director.)
  db.exec(sql"""CREATE TABLE IF NOT EXISTS directors (
                 movie TEXT REFERENCES imdb_db(id) ON DELETE CASCADE,
                 director TEXT,
                 PRIMARY KEY (movie, director)
              )""")

  var parser: CSVParser
  parser.open(loc, separator='\t', quote='\0')

  let movies = map(db.getAllRows(sql"SELECT id FROM imdb_db"), proc(x: Row): string = x[0]).toHashSet
  # echo movies

  # Discarding the true or false row exists boolean
  discard parser.readRow()
  let
    cols = parser.row
    id = cols.find("tconst")
    directors = cols.find("directors")

  var prep = db.prepare("INSERT INTO directors (movie, director) VALUES (?, ?)")
  db.exec(sql"BEGIN TRANSACTION")

  while parser.readRow():
    # Skip ids that aren't movies
    if not(parser.row[id] in movies): continue
    # Movies might have more than one director, this ensures we insert all
    # of them into the directors table.
    let inner_directors = parser.row[directors].split(",")
    for dir in inner_directors:
      prep.bind_param(1, parser.row[id])
      prep.bind_param(2, dir)

      db.exec(prep)
      discard reset(prep.PStmt)

  db.exec(sql"END TRANSACTION")

  # If you don't do this the db will explode when you try do anything.
  prep.finalize()

  # Always want to close when you're done for memory purposes!
  parser.close()

  # db.exec(sql"DELETE FROM directors WHERE (SELECT movie FROM directors) NOT IN (SELECT id FROM imdb_db")

proc initialize_movies*(name: string = "title.basics.tsv") =
  # Checks to see if the table already exists and if it does we bail
  if db.getValue(sql"SELECT name FROM sqlite_master WHERE type='table' AND name='imdb_db'") != "":
    echo "Movies table detected"
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

  # Discarding the true or false row exists boolean
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
  var search_name = name.replace("_", "\\_") # For searching for apostrophes
  search_name = search_name.replace("%", "\\%")

  var
    search_string = "SELECT * FROM imdb_db WHERE name LIKE ?"
    prep = db.prepare(search_string)

  if "year" in params:
    let year = params[params.find("year") + 1]
    search_string = search_string & &" AND year=?"

    prep.finalize() # Finalize the random other prepared statement.
    prep = db.prepare(search_string)
    prep.bindParam(2, year)

  prep.bindParam(1, &"%{search_name}%")
  result = db.getAllRows(prep)

  # If you don't do this the db will explode when you try do anything.
  prep.finalize()


proc find_person*(name: string): seq[Row] =
  let search_string = "SELECT * FROM people WHERE name LIKE ?"
  var prep = db.prepare(search_string)

  prep.bindParam(1, &"%{name}%")
  result = db.getAllRows(prep)

  # If you don't do this the db will explode when you try do anything.
  prep.finalize()