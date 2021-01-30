import db_sqlite
import marshal
import os
import streams
import strformat
import times

import imdb
import options
import parser
import ui_helper

var cmd: string

echo "Initializing db, please hold a moment..."
var t1 = cpuTime()
initialize_movies() # Actually initializes the database.
initialize_directors()
initialize_people()

var
  num = db.getValue(sql"SELECT COUNT(ALL) from imdb_db")
  t2 = cpuTime()

# Creates the ranking table if it does not exist. We do not modify this at
# at startup so I see no need to abstract this single line to a method.
db.exec(sql"""CREATE TABLE IF NOT EXISTS ranking (
                 id   TEXT NOT NULL PRIMARY KEY,
                 rank INT,
                 date DATE
              )""")
let
  num_ranked = db.getValue(sql"SELECT COUNT(ALL) from ranking")
  options_loc = getAppDir() / "options.txt"

if not fileExists(options_loc):
  echo "options.txt not found, creating options file."
  var out_strm = newFileStream(options_loc, fmWrite)
  out_strm.store(active_options)
  out_strm.close()
else:
  var strm = newFileStream(options_loc, fmRead)
  strm.load(active_options)
  strm.close()

echo &"Initialization complete in {t2 - t1} seconds."
echo &"Found {num} movies in database."
echo &"You have ranked {num_ranked} movies!"

while true:
  echo &"What would you like to do?"
  cmd = receive_command()

  if cmd != "":
    decrypt_command(cmd)

  # flushFile(fileLog.file)