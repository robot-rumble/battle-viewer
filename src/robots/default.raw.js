function _robot(state, unit, debug) {
  if (state.turn % 2 === 0) {
    return move(Direction.East)
  } else {
    return attack(Direction.South)
  }
}
