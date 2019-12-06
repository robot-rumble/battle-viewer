# noinspection PyUnresolvedReferences
def robot(turn, robot):
  if turn % 2 == 0:
    move('right')
  else:
    attack('down')
