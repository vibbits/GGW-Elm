module Admin exposing (..)

import Auth exposing (User)
import Element exposing (..)
import Element.Border as Border
import Element.Font as Font
import Interface exposing (columnTitle)
import Json.Decode as Decode
import Molecules exposing (Backbone, Level0, Level1, Vector(..), vectorDecoder)


type alias Group =
    { name : String
    }


type AdminData
    = NoData
    | Users (List User)
    | Groups (List Group)
    | Constructs (List Vector)


view : AdminData -> Element msg
view data =
    case data of
        NoData ->
            el [ padding 10 ] (text "No data")

        Users users ->
            usersTable users

        Groups groups ->
            groupsTable groups

        Constructs constructs ->
            vectorsTable constructs


usersTable : List User -> Element msg
usersTable users =
    let
        viewData : String -> Element msg
        viewData d =
            el
                [ Border.width 1
                , padding 10
                ]
                (text d)
    in
    el
        [ padding 10
        , width fill
        , height fill
        ]
        (table
            [ width fill
            , height fill
            , Border.width 1
            , Font.size 15
            ]
            { data = users
            , columns =
                [ { header = columnTitle "id"
                  , width = fill
                  , view = viewData << String.fromInt << .id
                  }
                , { header = columnTitle "Role"
                  , width = fill
                  , view = viewData << .role
                  }
                , { header = columnTitle "Name"
                  , width = fill
                  , view = viewData << Maybe.withDefault "[not set]" << .name
                  }
                ]
            }
        )


groupsTable : List Group -> Element msg
groupsTable groups =
    let
        viewData : String -> Element msg
        viewData d =
            el
                [ Border.width 1
                , padding 10
                ]
                (text d)
    in
    el
        [ padding 10
        , width fill
        , height fill
        ]
        (table
            [ width fill
            , height fill
            , Border.width 1
            , Font.size 15
            ]
            { data = groups
            , columns =
                [ { header = columnTitle "Name"
                  , width = fill
                  , view = viewData << .name
                  }
                ]
            }
        )


vectorsTable : List Vector -> Element msg
vectorsTable vectors =
    let
        viewData : String -> Element msg
        viewData d =
            el
                [ Border.width 1
                , padding 10
                ]
                (text d)

        vecData :
            Vector
            ->
                { id : Int
                , name : String
                , location : Int
                , responsible : String
                , group : String
                }
        vecData vec =
            case vec of
                BackboneVec c ->
                    { id = c.id
                    , name = c.name
                    , location = c.location
                    , responsible = c.responsible
                    , group = c.group
                    }

                Level0Vec c ->
                    { id = c.id
                    , name = c.name
                    , location = c.location
                    , responsible = c.responsible
                    , group = c.group
                    }

                LevelNVec c ->
                    { id = c.id
                    , name = c.name
                    , location = c.location
                    , responsible = c.responsible
                    , group = c.group
                    }
    in
    el
        [ padding 10
        , width fill
        , height fill
        ]
        (table
            [ width fill
            , height fill
            , Border.width 1
            , Font.size 15
            ]
            { data = vectors
            , columns =
                [ { header = columnTitle "id"
                  , width = fill
                  , view = viewData << String.fromInt << .id << vecData
                  }
                , { header = columnTitle "Name"
                  , width = fill
                  , view = viewData << .name << vecData
                  }
                , { header = columnTitle "Location"
                  , width = fill
                  , view = viewData << String.fromInt << .location << vecData
                  }
                , { header = columnTitle "Responsible"
                  , width = fill
                  , view = viewData << .responsible << vecData
                  }
                , { header = columnTitle "Group"
                  , width = fill
                  , view = viewData << .group << vecData
                  }
                ]
            }
        )



-- { "label": "users", "data": [] }
-- { "label": "groups", "data": [] }
-- { "label": "constructs", "data": [] }


decoder : Decode.Decoder AdminData
decoder =
    Decode.field "label" Decode.string
        |> Decode.andThen
            (\label ->
                case label of
                    "users" ->
                        Decode.field "data" (Decode.list userDecoder)
                            |> Decode.map Users

                    "groups" ->
                        Decode.field "data" (Decode.list groupDecoder)
                            |> Decode.map Groups

                    "constructs" ->
                        Decode.field "data" vectorDecoder
                            |> Decode.map Constructs

                    _ ->
                        Decode.fail "Not admin data"
            )


userDecoder : Decode.Decoder User
userDecoder =
    Decode.map3 (\id name role -> User id name role "")
        (Decode.field "id" Decode.int)
        (Decode.field "name" (Decode.nullable Decode.string))
        (Decode.field "role" Decode.string)


groupDecoder : Decode.Decoder Group
groupDecoder =
    Decode.map Group Decode.string
