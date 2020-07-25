import parsecsv

# import logging

import os
import sequtils
import strutils
import strformat
import system


type
  IMDB* = ref object
    # Sequences storing the list of movies, the years, and the ids.
    # Helper methods exist to take a movie name or id and find relevant
    # information on that movie in the tsv files, things like directors writers
    # and principal cast members.
    movies*: seq[string]
    ids*: seq[string]
    years*: seq[string]

    movies_lower: seq[string]

proc initialize_movies*(name: string = "title_reduced.tsv"): IMDB =
  # Initialize the database sequences to be empty to start with.
  var ids: seq[string] = @[]
  var movies: seq[string] = @[]
  var years: seq[string] = @[]

  # For future reference note that format of the tsv is as follows for the header:
  # tconst, movie, primarytitle, originaltitle, isadult, startyear, endyear, runtime, genres
  # Original title is the original language form of the title
  let loc = getAppDir() / name
  # Idiot proofing.
  if not fileExists(loc):
    # logging.error("File not found!")
    # logging.error(&"Attempted to load {name}")
    raise newException(IOError, "File not found!")

  var parser: CsvParser
  parser.open(name, separator='\t')
  # For future reference so we know file loading succeeded
  # logging.debug(&"Loaded IMDB file: {weights_name}")

  while readRow(parser):
    # I probably shouldn't hard code this but i'll figure out a way not to later
    ids.add(parser.row[0])
    movies.add(parser.row[2])
    years.add(parser.row[5])

  # Always want to close when you're done for memory puposes!
  parser.close()

  result = IMDB(ids: ids, movies: movies, years: years, movies_lower: movies.map(proc(x: string): string = x.toLower()))

# Looks for the movie you wanted in the imdb database you loaded
# the more recent one you loaded the better your chances are.
proc find*(db: IMDB, name: string): int =
  result = db.movies_lower.find(name)
