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
import update

echo "Initializing db, please hold a moment..."
var
  cmd: string
  t1 = cpuTime()
  should_update = should_update()

if should_update:
  download_dataset()

initialize_movies(should_update=should_update) # Actually initializes the database.

# Load the directors and writers here.
# Do the link table first since we only load the people who
# direct or write, not act.
initialize_crew(crew="director", should_update=should_update)
initialize_crew(crew="writer", should_update=should_update)
initialize_people(should_update=should_update)

# Recording this update for future should_update() calls.
# Do this after initialization because if a file isn't found init will fail
# And by extension so will the update.
if should_update:
  write_update_time()

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