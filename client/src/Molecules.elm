module Molecules exposing
    ( Backbone
    , Bsa1Overhang(..)
    , Bsmb1Overhang(..)
    , Level0
    , allOverhangs
    , backboneDecoder
    , initLevel0
    , level0Decoder
    , overhangs
    , showBsa1Overhang
    , showBsmb1Overhang
    )

import Dict exposing (Dict)
import Json.Decode as Decode
import Json.Decode.Pipeline as JDP


{-| What is this?
-}
type Bsa1Overhang
    = A__B
    | A__G
    | B__C
    | C__D
    | C__G
    | D__E
    | D__G
    | E__F
    | E__G
    | F__G


{-| What is this?
-}
type Bsmb1Overhang
    = W__X
    | W__Z
    | X__Y
    | X__Z
    | Y__Z


{-| What is this?
-}
type alias Backbone =
    { name : String
    , mPGBNumber : String
    , bsa1Overhang : Maybe Bsa1Overhang
    , bsmb1_overhang : Maybe Bsmb1Overhang
    , sequence : String
    }


{-| What is this?
-}
type alias Level0 =
    { name : String
    , mPG0Number : String
    , bsa1_overhang : Bsa1Overhang
    , sequence : String
    }


initLevel0 : Level0
initLevel0 =
    { name = ""
    , mPG0Number = ""
    , bsa1_overhang = A__B
    , sequence = ""
    }


overhangs : Dict Int (List Bsa1Overhang)
overhangs =
    Dict.fromList
        [ ( 3, [ A__B, B__C, C__G ] )
        , ( 4, [ A__B, B__C, C__D, D__G ] )
        , ( 5, [ A__B, B__C, C__D, D__E, E__G ] )
        , ( 6, [ A__B, B__C, C__D, D__E, E__F, F__G ] )
        ]


allOverhangs : List Bsa1Overhang
allOverhangs =
    [ A__B
    , A__G
    , B__C
    , C__D
    , C__G
    , D__E
    , D__G
    , E__F
    , E__G
    , F__G
    ]


level0Decoder : Decode.Decoder Level0
level0Decoder =
    let
        decodeOverhang : String -> Decode.Decoder Bsa1Overhang
        decodeOverhang str =
            case parseBsa1Overhang (String.trim str) of
                Just oh ->
                    Decode.succeed oh

                _ ->
                    Decode.fail "Not a valid overhang"
    in
    Decode.succeed Level0
        |> JDP.required "name" Decode.string
        |> JDP.required "id" (Decode.int |> Decode.map String.fromInt)
        |> JDP.required "bsa1_overhang"
            (Decode.string
                |> Decode.andThen decodeOverhang
            )
        |> JDP.required "sequence" Decode.string


backboneDecoder : Decode.Decoder Backbone
backboneDecoder =
    Decode.succeed Backbone
        |> JDP.required "name" Decode.string
        |> JDP.required "id" (Decode.int |> Decode.map String.fromInt)
        |> JDP.optional "bsa1_overhang"
            (Decode.string
                |> Decode.map (String.trim >> parseBsa1Overhang)
            )
            Nothing
        |> JDP.optional "bsmb1_overhang"
            (Decode.string
                |> Decode.map (String.trim >> parseBsmb1Overhang)
            )
            Nothing
        |> JDP.required "sequence" Decode.string


parseBsa1Overhang : String -> Maybe Bsa1Overhang
parseBsa1Overhang str =
    case str of
        "AB" ->
            Just A__B

        "AG" ->
            Just A__G

        "BC" ->
            Just B__C

        "CD" ->
            Just C__D

        "CG" ->
            Just C__G

        "DE" ->
            Just D__E

        "DG" ->
            Just D__G

        "EF" ->
            Just E__F

        "EG" ->
            Just E__G

        "FG" ->
            Just F__G

        _ ->
            Nothing


parseBsmb1Overhang : String -> Maybe Bsmb1Overhang
parseBsmb1Overhang str =
    case str of
        "WX" ->
            Just W__X

        "WZ" ->
            Just W__Z

        "XY" ->
            Just X__Y

        "XZ" ->
            Just X__Z

        "YZ" ->
            Just Y__Z

        _ ->
            Nothing


showBsa1Overhang : Bsa1Overhang -> String
showBsa1Overhang bsa1_overhang =
    case bsa1_overhang of
        A__B ->
            "A__B"

        A__G ->
            "A__G"

        B__C ->
            "B__C"

        C__D ->
            "C__D"

        C__G ->
            "C__G"

        D__E ->
            "D__E"

        D__G ->
            "D__G"

        E__F ->
            "E__F"

        E__G ->
            "E__G"

        F__G ->
            "F__G"


showBsmb1Overhang : Bsmb1Overhang -> String
showBsmb1Overhang bsmb1 =
    case bsmb1 of
        W__X ->
            "W__X"

        W__Z ->
            "W__Z"

        X__Y ->
            "X__Y"

        X__Z ->
            "X__Z"

        Y__Z ->
            "Y__Z"
