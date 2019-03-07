module LocalServer exposing (..)

import ServerData as D

-- TEST DATA

e1 : D.Entity
e1 = D.Entity 0 D.Player D.Red (D.Point 0 0) (D.Attack (D.Point 1 0))

e2 : D.Entity
e2 = D.Entity 1 D.Block D.Blue (D.Point 1 1) D.None

p : D.Packet
p = D.Packet 0 [e1, e2]

-- Actual verification

verifyMove : D.Entity -> D.Entity -> Bool
verifyMove robotOriginal robotNew = 
  True
