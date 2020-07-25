import strformat
import strutils

import parser

var cmd: string

while true:
  echo &"What would you like to do?"
  cmd = receive_command()

  if cmd != "":
    decrypt_command(cmd)

  # flushFile(fileLog.file)