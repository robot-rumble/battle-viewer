from random import randrange


def _robot(state, unit, debug):
    """Attacks at an enemy adjacent to it if there
    is one, or else moves in a random direction"""
    x, y = unit.coords
    for enemy in state.objs_by_team(state.other_team):
        enemyX, enemyY = enemy.coords
        if y == enemyY and x + 1 == enemyX:
            direction = Direction.East
        elif y == enemyY and x - 1 == enemyX:
            direction = Direction.West
        elif x == enemyX and y + 1 == enemyY:
            direction = Direction.South
        elif x == enemyX and y - 1 == enemyY:
            direction = Direction.North
        else:
            continue
        return attack(direction)
    r = randrange(0, 4)
    direction = {
        0: Direction.East,
        1: Direction.West,
        2: Direction.South,
        3: Direction.North,
    }[r]
    return move(direction)
