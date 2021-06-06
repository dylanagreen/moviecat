import db_sqlite
import strformat
import strutils

import imdb
# import options
# import ranking
# import search
# import ui_helper

proc get_stats*() =
  let num_ranked = db.getValue(sql"SELECT COUNT(ALL) from ranking")

  echo &"You have ranked {num_ranked} movies!"
