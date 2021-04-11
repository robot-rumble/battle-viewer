module DefaultCode exposing (loadDefaultCode)

import Dict
import Tuple exposing (second)


pythonCode =
    """
def robot(state, unit):
    if state.turn % 2 == 0:
        return Action.move(Direction.East)
    else:
        return Action.attack(Direction.South)
"""


javascriptCode =
    """
function robot(state, unit) {
  if (state.turn % 2 === 0) {
    return Action.move(Direction.East)
  } else {
    return Action.attack(Direction.South)
  }
}
"""


loadDefaultCode : String -> String
loadDefaultCode lang =
    case lang of
        "Python" ->
            pythonCode

        "Javascript" ->
            javascriptCode

        _ ->
            pythonCode
