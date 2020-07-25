import strformat
import strutils

var
  temp = @[1.0, 2.0, 3.0, 4.0, 5.0, 6.0, 7.0, 8.0, 9.0, 10.0]
  lower = 0
  upper = temp.len - 1
  mid = upper div 2
  cmd = ""
  not_found = true
  ind = -1


proc receive_command*(): string =
  result = stdin.readLine
  # logging.debug("Input: ", result)

proc auto_insert(val: float) =
  while not_found:
    # These first two if blocks handl edge cases.
    # If the lower and upper bounds are the same we need to check to see if the
    # "found" position is higher than the value we want to insert
    # If it is we insert before, if not we insert it after.
    if lower == upper:
      if temp[lower] > val:
        ind = lower
      else:
        ind = lower + 1
      break

    # If the lower is above the higher bound, then we insert at the lower
    # position, this occurs when we have moved below the bottom of the array.
    if lower > upper:
      ind = lower
      break

    # This is the normal binary search kind of algorithm
    # If the value is above the one at this index, the lower bound is moved above
    # the midpoint, otherwise the upper bound is moved below the midpoint.
    mid = (upper + lower) div 2
    if temp[mid] < val:
      lower = mid + 1
    elif temp[mid] > val:
      upper = mid - 1
    elif temp[mid] == val:
      ind = mid
      break

  temp.insert(val, ind)

proc decrypt_command(cmd: string) =
  if cmd.toLower() == "quit":
    quit()
  elif cmd.toLower() == "insert":
    auto_insert(7.0)
    echo temp


while true:
  echo &"What to do?"
  cmd = receive_command()

  if cmd != "":
    decrypt_command(cmd)

  # flushFile(fileLog.file)