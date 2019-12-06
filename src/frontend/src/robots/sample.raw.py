def robot(turn, robot):
  if turn % 2 == 0:
    return move("right")
  else:
    return attack("down")
