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
import times

import ../zip/zip/gzipfiles

let db* = open(getAppDir() / "cat.db", "", "", "")

type keywordType* = enum
  movie, year, watched, director, writer

# I keep this line here for testing rebuilding the imdb database from scratch.
# db.exec(sql"DROP TABLE IF EXISTS imdb_db")
# db.exec(sql"DROP TABLE IF EXISTS imdb_update")
# db.exec(sql"DROP TABLE IF EXISTS imdb_old")
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

  for c in @["Director", "Writer"]:
    # Getting the director from the relation table
    let crew = db.getAllRows(sql(&"SELECT {c.toLowerAscii} FROM {c.toLowerAscii}s WHERE movie=?"), movie[0])
    var name = ""

    if crew.len > 1:
      for i, n in crew:
        name &= db.getRow(sql"SELECT name FROM people WHERE id=?", n)[0]

        if i < (crew.len - 1):
          name &= ", "
    else:
      name = db.getRow(sql"SELECT name FROM people WHERE id=?", crew[0])[0]

    result &= &"{c}(s): {name}\n"


proc initialize_people*(name: string = "name.basics.tsv.gz", should_update = false) =
  var db_name = &"people"
  var exists_stmt = db.prepare(&"SELECT name FROM sqlite_master WHERE type='table' AND name='{db_name}'")
  # Checks to see if the table already exists and if it does we bail
  if db.getValue(exists_stmt) != "":
    echo &"{db_name} table detected"
    if should_update:
      echo &"Entering update mode..."
      db_name = &"people_update"
    else:
      exists_stmt.finalize()
      return

  exists_stmt.finalize()
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
  var create_stmt = db.prepare(&"""CREATE TABLE IF NOT EXISTS {db_name} (
                              id   TEXT PRIMARY KEY,
                              name TEXT NOT NULL
                              )""")
  db.exec(create_stmt)
  create_stmt.finalize()

  var parser: CSVParser
  let gz_stream = newGzFileStream(loc)
  parser.open(gz_stream, name, separator='\t', quote='\0')
  # For future reference so we know file loading succeeded
  # logging.debug(&"Loaded IMDB file: {name}")

  let directors = map(db.getAllRows(sql"SELECT director FROM directors"), proc(x: Row): string = x[0]).toHashSet
  let writers = map(db.getAllRows(sql"SELECT writer FROM writers"), proc(x: Row): string = x[0]).toHashSet

  # Discarding the true or false row exists boolean
  discard parser.readRow()
  let
    cols = parser.row
    id = cols.find("nconst")
    title = cols.find("primaryName")


  var prep = db.prepare(&"INSERT INTO {db_name} (id, name) VALUES (?, ?)")
  db.exec(sql"BEGIN TRANSACTION")

  while parser.readRow():
    # Skip people who didn't direct or write a movie.
    if not((parser.row[id] in directors) or (parser.row[id] in writers)): continue
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

  if should_update:
    # Rename the database old then move the new one into place
    db.exec(sql(&"ALTER TABLE people RENAME TO people_old"))
    db.exec(sql(&"ALTER TABLE {db_name} RENAME TO people"))

    # This left join keeps any entries that were in the old data base that
    # ARE NOT in the new one.
    db.exec(sql(&"""INSERT INTO people (id, name)
              SELECT * FROM people_old WHERE people_old.id NOT IN
              (SELECT id FROM people)"""))

    # Deleting the _old database.
    db.exec(sql(&"DROP TABLE IF EXISTS people_old"))

    echo "People table updated"
  else:
    echo "People table created"


proc initialize_crew*(name: string = "title.crew.tsv.gz", crew = "director", should_update = false) =
  var db_name = &"{crew}s"
  var exists_stmt = db.prepare(&"SELECT name FROM sqlite_master WHERE type='table' AND name='{db_name}'")
  # Checks to see if the table already exists and if it does we bail
  if db.getValue(exists_stmt) != "":
    echo &"{db_name} table detected"
    if should_update:
      echo &"Entering update mode..."
      db_name = &"{crew}s_update"
    else:
      exists_stmt.finalize()
      return

  exists_stmt.finalize()

  let loc = getAppDir() / name
  # Idiot proofing.
  if not fileExists(loc):
    # logging.error("File not found!")
    # logging.error(&"Attempted to load {name}")
    raise newException(IOError, &"File {loc} not found!")

  # Now make the directors/writers table.
  # We use a movie/crew combination as a primary key, which ensures
  # that each relation is unique, but allows multiple instances of
  # movies and crew (useful since a crew could direct/write more than one
  # movie and a movie could have more than one writer/director.)
  var create_stmt = db.prepare(&"""CREATE TABLE IF NOT EXISTS {db_name} (
                            movie TEXT REFERENCES imdb_db(id) ON DELETE CASCADE,
                            {crew} TEXT,
                            PRIMARY KEY (movie, {crew})
                            )""")
  db.exec(create_stmt)
  create_stmt.finalize()

  var parser: CSVParser
  let gz_stream = newGzFileStream(loc)
  parser.open(gz_stream, name, separator='\t', quote='\0')

  # Gets all the ids of movies included in the imdb_db
  let movies = map(db.getAllRows(sql"SELECT id FROM imdb_db"), proc(x: Row): string = x[0]).toHashSet

  # Discarding the true or false row exists boolean
  discard parser.readRow()
  let
    cols = parser.row
    id = cols.find("tconst")
    crew_person = cols.find(&"{crew}s")

  var prep = db.prepare(&"INSERT INTO {db_name} (movie, {crew}) VALUES (?, ?)")
  db.exec(sql"BEGIN TRANSACTION")

  while parser.readRow():
    # Skip ids that aren't movies
    if not(parser.row[id] in movies): continue
    # Movies might have more than one director, this ensures we insert all
    # of them into the directors table.
    let inner_crews = parser.row[crew_person].split(",")
    for c in inner_crews:
      prep.bind_param(1, parser.row[id])
      prep.bind_param(2, c)

      db.exec(prep)
      discard reset(prep.PStmt)

  db.exec(sql"END TRANSACTION")

  # If you don't do this the db will explode when you try do anything.
  prep.finalize()

  # Always want to close when you're done for memory purposes!
  parser.close()

  if should_update:
    # Rename the database old then move the new one into place
    db.exec(sql(&"ALTER TABLE {crew}s RENAME TO {crew}s_old"))
    db.exec(sql(&"ALTER TABLE {db_name} RENAME TO {crew}s"))

    # This left join keeps any entries that were in the old database that
    # ARE NOT in the new one. This is for movies you may have ranked but
    # that IMDB later "reclassified" to not be a movie, and so will be skipped
    # when parsing the tsv.
    db.exec(sql(&"""INSERT INTO {crew}s (movie, {crew})
              SELECT * FROM {crew}s_old WHERE {crew}s_old.movie NOT IN
              (SELECT movie FROM {crew}s)"""))

    # Deleting the _old database.
    db.exec(sql(&"DROP TABLE IF EXISTS {crew}s_old"))


    echo &"{crew}s table updated"
  else:
    echo &"{crew}s table created"

proc initialize_movies*(name: string = "title.basics.tsv.gz", should_update = false) =
  var db_name = "imdb_db"
  var exists_stmt = db.prepare(&"SELECT name FROM sqlite_master WHERE type='table' AND name='{db_name}'")
  # Checks to see if the table already exists and if it does we bail
  if db.getValue(exists_stmt) != "":
    echo "Movies table detected"
    if should_update:
      echo &"Entering update mode..."
      db_name = "imdb_update"
    else:
      exists_stmt.finalize()
      return

  exists_stmt.finalize()

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
  var create_stmt = db.prepare(&"""CREATE TABLE IF NOT EXISTS {db_name} (
                 id   TEXT PRIMARY KEY,
                 name TEXT NOT NULL,
                 year INT
                 )""")
  db.exec(create_stmt)
  create_stmt.finalize()

  var parser: CSVParser
  let gz_stream = newGzFileStream(loc)
  parser.open(gz_stream, name, separator='\t', quote='\0')
  # For future reference so we know file loading succeeded
  # logging.debug(&"Loaded IMDB file: {name}")

  # Discarding the true or false row exists boolean
  discard parser.readRow()
  let
    cols = parser.row
    id = cols.find("tconst")
    title = cols.find("primaryTitle")
    year = cols.find("startYear")


  var prep = db.prepare(&"INSERT INTO {db_name} (id, name, year) VALUES (?, ?, ?)")
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

  db.exec(sql"END TRANSACTION")

  # If you don't do this the db will explode when you try do anything.
  prep.finalize()

  # Always want to close when you're done for memory purposes!
  parser.close()

  if should_update:
    var t1 = cpuTime()
    # Rename the database old then move the new one into place
    db.exec(sql"ALTER TABLE imdb_db RENAME TO imdb_old")
    db.exec(sql"ALTER TABLE imdb_update RENAME TO imdb_db")

    # This left join keeps any entries that were in the old database that
    # ARE NOT in the new one. This is for movies you may have ranked but
    # that IMDB later "reclassified" to not be a movie, and so will be skipped
    # when parsing the tsv.
    db.exec(sql"""INSERT INTO imdb_db (id, name, year)
              SELECT * FROM imdb_old WHERE imdb_old.id NOT IN
              (SELECT id FROM imdb_db)""")

    # Deleting the imdb_old database.
    db.exec(sql"DROP TABLE IF EXISTS imdb_old")
    var t2 = cpuTime()
    echo &"Table update took {t2 - t1} seconds."

# Looks for the movie you wanted in the imdb database you loaded.
proc find_movie_db*(name: string, params: seq[string]): seq[Row] =
  # Need to insert the magic % wildcards before and after to search for names
  # that include the search string
  var search_name = name.replace("_", "\\_") # For searching for apostrophes
  search_name = search_name.replace("%", "\\%")

  var
    search_string = "SELECT * FROM imdb_db A WHERE A.name LIKE ?"
    param_num = 2

  # First assemble the search string
  # I actually search this order specifically because I want the year
  # param to be first in the search string.
  for opt in ["year", "writer", "director"]:
    if opt in params:
      if opt == "director":
        search_string &= " AND A.id in (SELECT B.movie FROM directors B WHERE B.director=?)"
      elif opt == "writer":
        search_string &= " AND A.id in (SELECT B.movie FROM writers B WHERE B.writer=?)"
      elif opt == "year":
        search_string &= " AND A.year=?"

  # then bind the params after preparing the prepared statement.
  var prep = db.prepare(search_string)
  prep.bindParam(1, &"%{search_name}%")
  for opt in ["year", "writer", "director"]:
    if opt in params:
      let param_data = params[params.find($opt) + 1]
      prep.bindParam(param_num, param_data)
      param_num += 1

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


proc recent*() =
  # Proc to find your most recently ranked move
  let
    ranking = db.getRow(sql"SELECT * FROM ranking ORDER BY date DESC LIMIT 1")
    movie = db.getRow(sql"SELECT * FROM imdb_db WHERE id = ?", ranking[0])

  echo &"Most recently watched movie was watched on {ranking[^1]}:"
  echo movie_row_to_string(movie)

