export default {
  Javascript: `
function robot(state, unit) {
  if (state.turn % 2 === 0) {
    return Action.move(Direction.East)
  } else {
    return Action.attack(Direction.South)
  }
}
  `,
  Python: `
def robot(state, unit):
    if state.turn % 2 == 0:
        return Action.move(Direction.East)
    else:
        return Action.attack(Direction.South)
`,
}
