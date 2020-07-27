import db_sqlite
import strformat
import times

import imdb
import parser

var cmd: string

echo "Initializing db, please hold a moment..."
var t1 = cpuTime()
initialize_movies() # Actually initializes the database.
var
  num = db.getValue(sql"SELECT COUNT(ALL) from imdb_db")
  t2 = cpuTime()

# Creates the ranking table if it does not exist. We do not modify this at
# at startup so I see no need to abstract this single line to a method.
db.exec(sql"""CREATE TABLE IF NOT EXISTS ranking (
                 id   TEXT NOT NULL PRIMARY KEY,
                 rank INT
              )""")

var num_ranked = db.getValue(sql"SELECT COUNT(ALL) from ranking")

echo &"Initialization complete in {t2 - t1} seconds."
echo &"Found {num} movies in database."
echo &"You have ranked {num_ranked} movies!"

while true:
  echo &"What would you like to do?"
  cmd = receive_command()

  if cmd != "":
    decrypt_command(cmd)

  # flushFile(fileLog.file)