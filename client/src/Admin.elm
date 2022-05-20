module Admin exposing (..)

import Auth exposing (User)
import Element exposing (..)
import Element.Border as Border
import Element.Font as Font
import Interface exposing (columnTitle)
import Json.Decode as Decode


type alias Group =
    {}


type alias Construct =
    {}


type AdminData
    = NoData
    | Users (List User)
    | Groups (List Group)
    | Constructs (List Construct)


view : AdminData -> Element msg
view data =
    case data of
        NoData ->
            el [ padding 10 ] (text "No data")

        Users users ->
            usersTable users

        Groups groups ->
            text "Groups"

        Constructs constructs ->
            text "Constructs"


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
                        Decode.field "data" (Decode.list constructDecoder)
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
    Decode.succeed {}


constructDecoder : Decode.Decoder Construct
constructDecoder =
    Decode.succeed {}
