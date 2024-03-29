module Molecules exposing
    ( Application(..)
    , Backbone
    , Bsa1Overhang(..)
    , Bsmb1Overhang(..)
    , Level0
    , Level1
    , Vector(..)
    , allBsa1Overhangs
    , allBsmbs1Overhangs
    , initBackbone
    , initLevel0
    , initLevel1
    , overhangs
    , showBsa1Overhang
    , showBsmb1Overhang
    , vectorDecoder
    , vectorDecoder_
    , vectorEncoder
    )

import Dict exposing (Dict)
import Json.Decode as Decode
import Json.Decode.Pipeline as JDP
import Json.Encode as Encode
import Maybe.Extra exposing (toList)


{-| All possible applications for a Level 1 construct
-}
type Application
    = Standard
    | Five
    | FiveAC
    | Four
    | FourAC
    | Three
    | ThreeAC


{-| All possible overhangs that are produced by a BsaI digest of a vector.
-}
type Bsa1Overhang
    = A__B
    | A__C
    | A__G
    | B__C
    | C__D
    | C__G
    | D__E
    | D__G
    | E__F
    | E__G
    | F__G


{-| All possible overhangs that are produced by a BsmbI digest of a vector.
-}
type Bsmb1Overhang
    = W__X
    | W__Z
    | X__Y
    | X__Z
    | Y__Z


{-| All possible types of Vector
-}
type Vector
    = BackboneVec Backbone
    | Level0Vec Level0
    | LevelNVec Level1


{-| Vector that accept one or more donorvector. Also called a destination vector.
-}
type alias Backbone =
    { id : Int
    , name : String
    , location : Int
    , bsa1Overhang : Maybe Bsa1Overhang
    , bsmb1Overhang : Maybe Bsmb1Overhang
    , sequenceLength : Int
    , bacterialStrain : Maybe String
    , responsible : String -- TODO: Owner of the Level 0 element = User that adds the vector.
    , group : String
    , selection : Maybe String
    , cloningTechnique : Maybe String
    , notes : Maybe String
    , reaseDigest : Maybe String
    , date : Maybe String
    , vectorType : Maybe String
    , genbankContent : Maybe String
    }


{-| Type of donor vector which are used to construct a Level 1 Vector.
-}
type alias Level0 =
    { id : Int
    , name : String
    , location : Int
    , bsa1Overhang : Bsa1Overhang
    , sequenceLength : Int
    , bacterialStrain : Maybe String
    , responsible : String -- TODO: Owner of the Level 0 element = User that adds the vector.
    , group : String
    , selection : Maybe String
    , cloningTechnique : Maybe String
    , isBsmb1Free : Maybe Bool
    , notes : Maybe String
    , reaseDigest : Maybe String
    , date : Maybe String
    , genbankContent : Maybe String
    }


{-| Type of vector constructed by combining
a Backbone with one or multiple Level 0 verctors.
-}
type alias Level1 =
    { id : Int
    , name : String
    , location : Int
    , bacterialStrain : Maybe String
    , bsmb1Overhang : Maybe Bsmb1Overhang
    , responsible : String
    , group : String
    , selection : Maybe String
    , notes : Maybe String
    , sequenceLength : Int
    , reaseDigest : Maybe String
    , inserts : List Level0
    , backbone : Maybe Backbone
    , date : Maybe String
    , genbankContent : Maybe String
    }


initLevel1 : Level1
initLevel1 =
    { id = 0
    , name = ""
    , location = 1
    , bacterialStrain = Nothing
    , bsmb1Overhang = Nothing
    , responsible = ""
    , group = ""
    , selection = Nothing
    , notes = Just ""
    , sequenceLength = 0
    , reaseDigest = Nothing
    , inserts = []
    , backbone = Nothing
    , date = Nothing
    , genbankContent = Nothing
    }


initLevel0 : Level0
initLevel0 =
    { id = 0
    , name = ""
    , location = 0
    , bsa1Overhang = A__B
    , sequenceLength = 0
    , bacterialStrain = Nothing
    , responsible = "" -- TODO: Owner of the Level 0 element = User that adds the vector.
    , group = ""
    , selection = Nothing
    , cloningTechnique = Nothing
    , isBsmb1Free = Just False
    , notes = Nothing
    , reaseDigest = Nothing
    , date = Nothing
    , genbankContent = Nothing
    }


initBackbone : Backbone
initBackbone =
    { id = 0
    , name = ""
    , location = 0
    , bsa1Overhang = Nothing
    , bsmb1Overhang = Nothing
    , sequenceLength = 0
    , bacterialStrain = Nothing
    , responsible = "" -- TODO: Owner of the Level 0 element = User that adds the vector.
    , group = ""
    , selection = Nothing
    , cloningTechnique = Nothing
    , notes = Nothing
    , reaseDigest = Nothing
    , date = Nothing
    , vectorType = Nothing
    , genbankContent = Nothing
    }


overhangs : Dict String (List Bsa1Overhang)
overhangs =
    Dict.fromList
        [ ( "3", [ A__B, B__C, C__G ] )
        , ( "4", [ A__B, B__C, C__D, D__G ] )
        , ( "5", [ A__B, B__C, C__D, D__E, E__G ] )
        , ( "6", [ A__B, B__C, C__D, D__E, E__F, F__G ] )

        -- New applications to implement:
        , ( "3AC", [ A__C, C__D, D__G ] )
        , ( "4AC", [ A__C, C__D, D__E, E__G ] )
        , ( "5AC", [ A__C, C__D, D__E, E__F, F__G ] )
        ]


allBsa1Overhangs : List Bsa1Overhang
allBsa1Overhangs =
    [ A__B
    , A__C
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


allBsmbs1Overhangs : List Bsmb1Overhang
allBsmbs1Overhangs =
    [ W__X
    , W__Z
    , X__Y
    , X__Z
    , Y__Z
    ]



-- Decoders


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
        |> JDP.required "id" Decode.int
        |> JDP.required "name" Decode.string
        |> JDP.required "location" Decode.int
        |> JDP.required "bsa1_overhang"
            (Decode.string
                |> Decode.andThen decodeOverhang
            )
        |> JDP.required "sequence_length" Decode.int
        |> JDP.optional "bacterial_strain" (Decode.maybe Decode.string) Nothing
        |> JDP.required "responsible" Decode.string
        |> JDP.required "group" Decode.string
        |> JDP.optional "selection" (Decode.maybe Decode.string) Nothing
        |> JDP.optional "cloning_technique" (Decode.maybe Decode.string) Nothing
        |> JDP.optional "isBsmb1Free"
            (Decode.string
                |> Decode.map (String.trim >> isBsmb1FreeToBool)
            )
            Nothing
        |> JDP.optional "notes" (Decode.maybe Decode.string) Nothing
        |> JDP.optional "reaseDigest" (Decode.maybe Decode.string) Nothing
        |> JDP.optional "date" (Decode.maybe Decode.string) Nothing
        |> JDP.hardcoded Nothing


backboneDecoder : Decode.Decoder Backbone
backboneDecoder =
    Decode.succeed Backbone
        |> JDP.required "id" Decode.int
        |> JDP.required "name" Decode.string
        |> JDP.required "location" Decode.int
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
        |> JDP.required "sequence_length" Decode.int
        |> JDP.optional "bacterial_strain" (Decode.maybe Decode.string) Nothing
        |> JDP.required "responsible" Decode.string
        |> JDP.required "group" Decode.string
        |> JDP.optional "selection" (Decode.maybe Decode.string) Nothing
        |> JDP.optional "cloning_technique" (Decode.maybe Decode.string) Nothing
        |> JDP.optional "notes" (Decode.maybe Decode.string) Nothing
        |> JDP.optional "reaseDigest" (Decode.maybe Decode.string) Nothing
        |> JDP.optional "date" (Decode.maybe Decode.string) Nothing
        |> JDP.optional "vector_type" (Decode.maybe Decode.string) Nothing
        |> JDP.hardcoded Nothing


level1Decoder : Decode.Decoder Level1
level1Decoder =
    let
        filterLevel0 : List Vector -> List Level0
        filterLevel0 vs =
            vs
                |> List.filterMap
                    (\v ->
                        case v of
                            Level0Vec vec ->
                                Just vec

                            _ ->
                                Nothing
                    )

        filterBackbone : List Vector -> Maybe Backbone
        filterBackbone vs =
            vs
                |> List.filterMap
                    (\v ->
                        case v of
                            BackboneVec vec ->
                                Just vec

                            _ ->
                                Nothing
                    )
                |> List.head
    in
    Decode.succeed Level1
        |> JDP.required "id" Decode.int
        |> JDP.required "name" Decode.string
        |> JDP.required "location" Decode.int
        |> JDP.optional "bacterial_strain" (Decode.maybe Decode.string) Nothing
        |> JDP.optional "bsmb1_overhang"
            (Decode.string
                |> Decode.map (String.trim >> parseBsmb1Overhang)
            )
            Nothing
        |> JDP.required "responsible" Decode.string
        |> JDP.required "group" Decode.string
        |> JDP.optional "selection" (Decode.maybe Decode.string) Nothing
        |> JDP.optional "notes" (Decode.maybe Decode.string) Nothing
        |> JDP.required "sequence_length" Decode.int
        |> JDP.optional "REase_digest" (Decode.maybe Decode.string) Nothing
        |> JDP.required "children" (vectorDecoder |> Decode.map filterLevel0)
        |> JDP.required "children" (vectorDecoder |> Decode.map filterBackbone)
        |> JDP.optional "date" (Decode.maybe Decode.string) Nothing
        |> JDP.hardcoded Nothing


vectorDecoder_ : Decode.Decoder Vector
vectorDecoder_ =
    Decode.field "level" Decode.int
        |> Decode.andThen
            (\level ->
                case level of
                    1 ->
                        Decode.andThen (Decode.succeed << BackboneVec) backboneDecoder

                    2 ->
                        Decode.andThen (Decode.succeed << Level0Vec) level0Decoder

                    3 ->
                        Decode.andThen (Decode.succeed << LevelNVec) level1Decoder

                    _ ->
                        Decode.fail "Unknow Level!"
            )


vectorDecoder : Decode.Decoder (List Vector)
vectorDecoder =
    Decode.list vectorDecoder_



-- Encoders


vectorEncoder : Vector -> Encode.Value
vectorEncoder vector =
    case vector of
        Level0Vec vec ->
            level0Encoder vec

        BackboneVec vec ->
            backboneEncoder vec

        LevelNVec vec ->
            levelNEncoder vec


backboneEncoder : Backbone -> Encode.Value
backboneEncoder backbone =
    Encode.object
        [ ( "name", Encode.string backbone.name )
        , ( "location", Encode.int backbone.location )
        , ( "bsa1_overhang"
          , Maybe.map (showBsa1Overhang >> Encode.string) backbone.bsa1Overhang
                |> Maybe.withDefault Encode.null
          )
        , ( "bsmb1_overhang"
          , Maybe.map (showBsmb1Overhang >> Encode.string) backbone.bsmb1Overhang
                |> Maybe.withDefault Encode.null
          )
        , ( "bacterial_strain"
          , Maybe.withDefault "" backbone.bacterialStrain
                |> Encode.string
          )
        , ( "responsible", Encode.string backbone.responsible )
        , ( "group", Encode.string backbone.group )
        , ( "selection"
          , Maybe.map Encode.string backbone.selection
                |> Maybe.withDefault Encode.null
          )
        , ( "cloning_technique"
          , Maybe.map Encode.string backbone.cloningTechnique
                |> Maybe.withDefault Encode.null
          )
        , ( "is_BsmB1_free"
          , Encode.null
          )
        , ( "notes"
          , Maybe.map Encode.string backbone.notes
                |> Maybe.withDefault Encode.null
          )
        , ( "REase_digest"
          , Maybe.map Encode.string backbone.reaseDigest
                |> Maybe.withDefault Encode.null
          )
        , ( "date"
          , Maybe.withDefault "" backbone.date
                |> Encode.string
          )
        , ( "experiment"
          , Maybe.withDefault "" backbone.vectorType
                |> Encode.string
          )
        , ( "genbank"
          , Maybe.map Encode.string backbone.genbankContent
                |> Maybe.withDefault Encode.null
          )
        , ( "level"
          , Encode.int 1
          )
        , ( "annotations"
          , Encode.list Encode.int []
          )
        , ( "references"
          , Encode.list Encode.int []
          )
        , ( "gateway_site"
          , Encode.string ""
          )
        , ( "children"
          , Encode.list Encode.int []
          )
        ]


level0Encoder : Level0 -> Encode.Value
level0Encoder level0 =
    Encode.object
        [ ( "name", Encode.string level0.name )
        , ( "location", Encode.int level0.location )
        , ( "bsa1_overhang"
          , level0.bsa1Overhang
                |> showBsa1Overhang
                |> Encode.string
          )
        , ( "bacterial_strain"
          , Maybe.withDefault "" level0.bacterialStrain
                |> Encode.string
          )
        , ( "responsible", Encode.string level0.responsible )
        , ( "group", Encode.string level0.group )
        , ( "selection"
          , Maybe.map Encode.string level0.selection
                |> Maybe.withDefault Encode.null
          )
        , ( "cloning_technique"
          , Maybe.map Encode.string level0.cloningTechnique
                |> Maybe.withDefault Encode.null
          )
        , ( "is_BsmB1_free"
          , case level0.isBsmb1Free of
                Nothing ->
                    Encode.null

                Just True ->
                    Encode.string "YES"

                Just False ->
                    Encode.string "NO"
          )
        , ( "notes"
          , Maybe.map Encode.string level0.notes
                |> Maybe.withDefault Encode.null
          )
        , ( "REase_digest"
          , Maybe.map Encode.string level0.reaseDigest
                |> Maybe.withDefault Encode.null
          )
        , ( "date"
          , Maybe.withDefault "" level0.date
                |> Encode.string
          )
        , ( "genbank"
          , Maybe.map Encode.string level0.genbankContent
                |> Maybe.withDefault Encode.null
          )
        , ( "level"
          , Encode.int 2
          )
        , ( "annotations"
          , Encode.list Encode.int []
          )
        , ( "references"
          , Encode.list Encode.int []
          )
        , ( "gateway_site"
          , Encode.string ""
          )
        , ( "children"
          , Encode.list Encode.int []
          )
        , ( "experiment"
          , Encode.string ""
          )
        ]


levelNEncoder : Level1 -> Encode.Value
levelNEncoder level1 =
    Encode.object
        [ ( "sequence_length", Encode.int level1.sequenceLength )
        , ( "name", Encode.string level1.name )
        , ( "location", Encode.int level1.location )
        , ( "bsa1_overhang", Encode.null )
        , ( "cloning_technique", Encode.null )
        , ( "bsmb1_overhang"
          , Maybe.map (showBsmb1Overhang >> Encode.string) level1.bsmb1Overhang
                |> Maybe.withDefault Encode.null
          )
        , ( "responsible", Encode.string <| level1.responsible )
        , ( "bacterial_strain"
          , Maybe.withDefault "" level1.bacterialStrain
                |> Encode.string
          )
        , ( "selection"
          , Maybe.map Encode.string level1.selection
                |> Maybe.withDefault Encode.null
          )
        , ( "group", Encode.string level1.group )
        , ( "notes"
          , Maybe.map Encode.string level1.notes
                |> Maybe.withDefault Encode.null
          )
        , ( "REase_digest"
          , Maybe.map Encode.string level1.reaseDigest
                |> Maybe.withDefault Encode.null
          )
        , ( "date"
          , Maybe.withDefault "" level1.date
                |> Encode.string
          )
        , ( "level"
          , Encode.int 3
          )
        , ( "annotations"
          , Encode.list Encode.int []
          )
        , ( "references"
          , Encode.list Encode.int []
          )
        , ( "gateway_site"
          , Encode.string ""
          )
        , ( "children"
          , Encode.list Encode.int
                (toList level1.backbone
                    |> List.map .id
                    |> List.append (List.map .id level1.inserts)
                )
          )
        , ( "experiment"
          , Encode.string ""
          )
        ]


parseBsa1Overhang : String -> Maybe Bsa1Overhang
parseBsa1Overhang str =
    case String.replace "_" "" str of
        "AB" ->
            Just A__B

        "AC" ->
            Just A__C

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
    case String.replace "_" "" str of
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

        A__C ->
            "A__C"

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


isBsmb1FreeToBool : String -> Maybe Bool
isBsmb1FreeToBool answer =
    case String.toUpper answer of
        "YES" ->
            Just True

        "NO" ->
            Just False

        _ ->
            Nothing
