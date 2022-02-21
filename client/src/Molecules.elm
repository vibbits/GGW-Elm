module Molecules exposing
    ( Backbone
    , Bsa1Overhang(..)
    , Bsmb1Overhang(..)
    , ChangeMol(..)
    , Level0
    , Level1
    , allOverhangs
    , backboneDecoder
    , initBackbone
    , initLevel0
    , initLevel1
    , interpretBackboneChange
    , interpretLevel0Change
    , level0Decoder
    , level1Decoder
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
    , mPGNumber : Int
    , bsa1Overhang : Maybe Bsa1Overhang
    , bsmb1Overhang : Maybe Bsmb1Overhang
    , sequence : String
    }


{-| What is this?
-}
type alias Level0 =
    { name : String
    , mPGNumber : Int
    , bsa1Overhang : Bsa1Overhang
    , sequence : String
    }


{-| What is this?
-}
type alias Level1 =
    { name : String
    , mPGNumber : Int
    , bsmb1Overhang : Maybe Bsmb1Overhang
    , responsible : String
    , notes : Maybe String
    , sequence : String
    , inserts : List Level0
    , backbone : Maybe Backbone
    }


initLevel1 : Level1
initLevel1 =
    { name = ""
    , mPGNumber = 1
    , bsmb1Overhang = Nothing
    , responsible = ""
    , notes = Just ""
    , sequence = ""
    , inserts = []
    , backbone = Nothing
    }


{-| Helper type to change Backbone or Level0 fields
-}
type ChangeMol
    = ChangeName String
    | ChangeMPG Int
    | ChangeBsa1 Bsa1Overhang


initLevel0 : Level0
initLevel0 =
    { name = ""
    , mPGNumber = 0
    , bsa1Overhang = A__B
    , sequence = ""
    }


initBackbone : Backbone
initBackbone =
    { name = ""
    , mPGNumber = 0
    , bsa1Overhang = Nothing
    , bsmb1Overhang = Nothing
    , sequence = ""
    }


interpretBackboneChange : ChangeMol -> Backbone -> Backbone
interpretBackboneChange msg bb =
    case msg of
        ChangeName name ->
            { bb | name = name }

        ChangeMPG mpg ->
            { bb | mPGNumber = mpg }

        ChangeBsa1 bsa1 ->
            { bb | bsa1Overhang = Just bsa1 }


interpretLevel0Change : ChangeMol -> Level0 -> Level0
interpretLevel0Change msg l0 =
    case msg of
        ChangeName name ->
            { l0 | name = name }

        ChangeMPG mpg ->
            { l0 | mPGNumber = mpg }

        ChangeBsa1 bsa1 ->
            { l0 | bsa1Overhang = bsa1 }


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


decodeOverhang : String -> Decode.Decoder Bsa1Overhang
decodeOverhang str =
    case parseBsa1Overhang (String.trim str) of
        Just oh ->
            Decode.succeed oh

        _ ->
            Decode.fail "Not a valid overhang"


level0Decoder : Decode.Decoder Level0
level0Decoder =
    Decode.succeed Level0
        |> JDP.required "name" Decode.string
        |> JDP.required "id" Decode.int
        |> JDP.required "bsa1_overhang"
            (Decode.string
                |> Decode.andThen decodeOverhang
            )
        |> JDP.required "sequence" Decode.string


backboneDecoder : Decode.Decoder Backbone
backboneDecoder =
    Decode.succeed Backbone
        |> JDP.required "name" Decode.string
        |> JDP.required "id" Decode.int
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


level1Decoder : Decode.Decoder Level1
level1Decoder =
    Decode.succeed Level1
        |> JDP.required "name" Decode.string
        |> JDP.required "mpg_number" Decode.int
        |> JDP.optional "bsmb1_overhang"
            (Decode.string
                |> Decode.map (String.trim >> parseBsmb1Overhang)
            )
            Nothing
        |> JDP.required "responsible" Decode.string
        |> JDP.optional "notes" (Decode.maybe Decode.string) Nothing
        |> JDP.required "sequence" Decode.string
        |> JDP.required "children" (Decode.list level0Decoder)
        -- TODO: This should be properly decoded
        |> JDP.hardcoded Nothing


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
