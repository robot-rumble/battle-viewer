module ServerData exposing (..)

-- type Data = SEntity Entity | SPacket Packet | SUserTeam UserTeam | SEntityType EntityType | SEntityAction EntityAction

type alias Entity = {
  id : Int,
  entityType : EntityType,
  team : UserTeam,
  position : Point,
  action : EntityAction}

type alias Packet = {
  time : Int,
  entities : List Entity}

type UserTeam = Red | Blue

type EntityType = Player | Block | Item

type EntityAction = None | Attack Point | Defend | Use Point | Move Point

type alias Point = {
  x : Int,
  y : Int}

entityToString : Entity -> String
entityToString entity = 
  "{id:" ++ String.fromInt(entity.id) ++
  ",entityType:" ++ entityTypeToString(entity.entityType) ++
  ",team:" ++ teamToString(entity.team) ++
  ",position:" ++ pointToString(entity.position) ++
  ",action:" ++ actionToString(entity.action) ++ "}"

packetToString : Packet -> String
packetToString packet =
  "{time:" ++ String.fromInt(packet.time) ++
  ",entities:["++
    String.concat(List.map (\e -> (entityToString e) ++ ",") packet.entities) ++
  "]}"

teamToString : UserTeam -> String
teamToString userTeam =
  case userTeam of
    Red ->
      "Red"
    Blue ->
      "Blue"

entityTypeToString : EntityType -> String
entityTypeToString entityType = 
  case entityType of
    Player ->
      "Player"
    Block ->
      "Block"
    Item ->
      "Item"

actionToString : EntityAction -> String
actionToString action = 
  case action of
    None ->
      "None"
    Attack point ->
      "Attack"
    Defend ->
      "Defend"
    Use point ->
      "Use"
    Move point ->
      "Move"

pointToString : Point -> String
pointToString point = 
  "{x:"++String.fromInt(point.x)++"y:"++String.fromInt(point.y)++"}"

importJson json = 
  json
