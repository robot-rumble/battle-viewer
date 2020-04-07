def _check_enum(val, options):
    if val not in options:
        options_string = " / ".join(options)
        raise Exception(f'"{val}" must be one of {options_string}')


def _direction_action(name):
    name = name.capitalize()

    def action(direction):
        direction = direction.capitalize()
        _check_enum(direction, ["Left", "Right", "Up", "Down"])
        return {"type_": name, "direction": direction}

    return action


move = _direction_action("Move")
attack = _direction_action("Attack")


# noinspection PyUnresolvedReferences,PyGlobalUndefined
def main(main_input, math_random):
    global obj_by_id, objs_by_team, ids_by_team, rand
    global obj_by_loc, id_by_loc, move, attack, other_team

    state = main_input["state"]
    team = main_input["team"]

    def obj_by_id(id):
        return state["objs"][id]

    def objs_by_team(team):
        return [obj_by_id(id) for id in ids_by_team(team)]

    def ids_by_team(team):
        return state["teams"][team]

    def obj_by_loc(x, y):
        id = id_by_loc(x, y)
        return id and obj_by_id(id)

    def id_by_loc(x, y):
        xs = state["map"][x]
        return xs and xs[y]

    if team == "Red":
        _other_team = "Blue"
    elif team == "Blue":
        _other_team = "Red"
    else:
        raise Exception("team is neither red nor blue")

    other_team = lambda: _other_team

    rand = lambda max, min: int(math_random() * (max - min + 1) + min)

    global current_action
    actions = {}

    for id in state["teams"][team]:
        try:
            robot
        except NameError:
            raise Exception('You must define a "robot" function.')
    if robot.__code__.co_argcount != 2:
        raise Exception(
            'Your "robot" function must accept two values: the current \
    turn and robot details.'
        )
    current_action = robot(state["turn"], state["objs"][id])
    if not current_action:
        raise Exception("Robot did not return an action!")
    actions[id] = current_action

    return {"actions": actions}
