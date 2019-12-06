def robot(turn, robot):
    """Attacks at an enemy adjacent to it, or else moves in a random direction"""
    x, y = robot["coords"]
    for enemy in objs_by_team(other_team()):
        enemyX, enemyY = enemy["coords"]
        if y == enemyY and x + 1 == enemyX:
            return attack("right")
        if y == enemyY and x - 1 == enemyX:
            return attack("left")
        if x == enemyX and y + 1 == enemyY:
            return attack("down")
        if x == enemyX and y - 1 == enemyY:
            return attack("up")
    r = rand(0, 5)
    if r == 1:
        direction = "right"
    elif r == 2:
        direction = "left"
    elif r == 3:
        direction = "down"
    else:
        direction = "up"
    return move(direction)
