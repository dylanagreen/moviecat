import parsecsv

# import logging

import os
import sequtils
import strutils
import strformat
import system


type
  Movie* = ref object
    # Movie objects store their name as well as a variety of information
    # on them. I should really just make a sql database of this tbh.
    name*: string
    name_lower: string
    id*: string
    year*: int

  IMDB* = ref object
    # Sequence of Movie objects.
    movies*: seq[Movie]


proc `$`*(movie: Movie): string =
  result = &"{movie.name} ({movie.id}): {movie.year}"

proc initialize_movies*(name: string = "title_reduced.tsv"): IMDB =
  # Initialize the database sequence to be empty to start with.
  var movies: seq[Movie] = @[]

  # For future reference note that format of the tsv is as follows for the header:
  # tconst, movie, primarytitle, originaltitle, isadult, startyear, endyear, runtime, genres
  # Original title is the original language form of the title
  let loc = getAppDir() / name
  # Idiot proofing.
  if not fileExists(loc):
    # logging.error("File not found!")
    # logging.error(&"Attempted to load {name}")
    raise newException(IOError, "File not found!")

  var parser: CSVParser
  parser.open(name, separator='\t')
  # For future reference so we know file loading succeeded
  # logging.debug(&"Loaded IMDB file: {name}")

  while readRow(parser):
    try:
      # I probably shouldn't hard code this but i'll figure out a way not to later
      movies.add(Movie(id: parser.row[0], name: parser.row[2],
                        name_lower: parser.row[2].toLower(), year: parseInt(parser.row[5])))
    except ValueError:
      # This ignores movies that are in development or don't have a proper year
      continue

  # Always want to close when you're done for memory puposes!
  parser.close()

  result = IMDB(movies: movies)

# Looks for the movie you wanted in the imdb database you loaded.
# The more recent one you loaded the better your chances are.
proc find*(db: IMDB, name: string): seq[Movie] =
  result = db.movies.filter(proc(x: Movie): bool = x.name_lower.contains(name))
