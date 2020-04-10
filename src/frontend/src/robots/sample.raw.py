def robot(state, unit):
  if state.turn % 2 == 0:
    return move(Direction.East)
  else:
    return attack(Direction.South)
