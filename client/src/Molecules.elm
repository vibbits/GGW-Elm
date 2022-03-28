module Molecules exposing
    ( Backbone
    , Bsa1Overhang(..)
    , Bsmb1Overhang(..)
    , ChangeMol(..)
    , Level0
    , Level1
    , Vector(..)
    , allBsa1Overhangs
    , allBsmbs1Overhangs
    , getBackboneFromLevel1
    , getInsertsFromLevel1
    , initBackbone
    , initLevel0
    , initLevel1
    , interpretBackboneChange
    , interpretLevel0Change
    , interpretLevel1Change
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
    { name : String
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
    { name : String
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
    { name : String
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
    { name = ""
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


{-| Helper type to change Backbone or Level0 fields
-}
type ChangeMol
    = ChangeName String
    | ChangeMPG Int
    | ChangeBsa1 Bsa1Overhang
    | ChangeBsmb1 Bsmb1Overhang
    | ChangeDate String
    | ChangeBacterialStrain String
    | ChangeResponsible String
    | ChangeGroup String
    | ChangeSelection String
    | ChangeCloningTechnique String
    | ChangeIsBsmB1Free Bool
    | ChangeNotes String
    | ChangeVectorType String
    | ChangeReaseDigest String
    | ChangeGB String
    | AppendInsert Level0
    | AppendBackbone Backbone
    | ResetInsertList
    | ResetAll


initLevel0 : Level0
initLevel0 =
    { name = ""
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
    { name = ""
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


interpretBackboneChange : ChangeMol -> Backbone -> Backbone
interpretBackboneChange msg bb =
    case msg of
        ChangeName name ->
            { bb | name = name }

        ChangeMPG loc ->
            { bb | location = loc }

        ChangeBsa1 bsa1 ->
            { bb | bsa1Overhang = Just bsa1 }

        ChangeBsmb1 bsmb1 ->
            { bb | bsmb1Overhang = Just bsmb1 }

        ChangeResponsible resp ->
            { bb | responsible = resp }

        ChangeGroup grp ->
            { bb | group = grp }

        ChangeSelection sel ->
            { bb | selection = Just sel }

        ChangeCloningTechnique cloneTech ->
            { bb | cloningTechnique = Just cloneTech }

        ChangeNotes nts ->
            { bb | notes = Just nts }

        ChangeReaseDigest rease ->
            { bb | reaseDigest = Just rease }

        ChangeDate dte ->
            { bb | date = Just dte }

        ChangeVectorType vt ->
            { bb | vectorType = Just vt }

        ChangeBacterialStrain bactStrain ->
            { bb | bacterialStrain = Just bactStrain }

        ChangeIsBsmB1Free _ ->
            bb

        ChangeGB content ->
            { bb | genbankContent = Just content }

        AppendInsert _ ->
            bb

        AppendBackbone _ ->
            bb

        ResetInsertList ->
            bb

        ResetAll ->
            bb


interpretLevel0Change : ChangeMol -> Level0 -> Level0
interpretLevel0Change msg l0 =
    case msg of
        ChangeName name ->
            { l0 | name = name }

        ChangeMPG loc ->
            { l0 | location = loc }

        ChangeBsa1 bsa1 ->
            { l0 | bsa1Overhang = bsa1 }

        ChangeBsmb1 _ ->
            l0

        ChangeBacterialStrain bactStrain ->
            { l0 | bacterialStrain = Just bactStrain }

        ChangeDate date ->
            { l0 | date = Just date }

        ChangeResponsible resp ->
            { l0 | responsible = resp }

        ChangeGroup grp ->
            { l0 | group = grp }

        ChangeSelection sel ->
            { l0 | selection = Just sel }

        ChangeCloningTechnique cloneTech ->
            { l0 | cloningTechnique = Just cloneTech }

        ChangeIsBsmB1Free answer ->
            { l0 | isBsmb1Free = Just answer }

        ChangeVectorType _ ->
            l0

        ChangeNotes nts ->
            { l0 | notes = Just nts }

        ChangeReaseDigest rease ->
            { l0 | reaseDigest = Just rease }

        ChangeGB content ->
            { l0 | genbankContent = Just content }

        AppendInsert _ ->
            l0

        AppendBackbone _ ->
            l0

        ResetInsertList ->
            l0

        ResetAll ->
            l0


interpretLevel1Change : ChangeMol -> Level1 -> Level1
interpretLevel1Change msg l1 =
    case msg of
        ChangeName name ->
            { l1 | name = name }

        ChangeMPG loc ->
            { l1 | location = loc }

        ChangeBsa1 _ ->
            l1

        ChangeBsmb1 _ ->
            l1

        ChangeBacterialStrain bactStrain ->
            { l1 | bacterialStrain = Just bactStrain }

        ChangeDate date ->
            { l1 | date = Just date }

        ChangeResponsible resp ->
            { l1 | responsible = resp }

        ChangeGroup grp ->
            { l1 | group = grp }

        ChangeSelection sel ->
            { l1 | selection = Just sel }

        ChangeCloningTechnique _ ->
            l1

        ChangeIsBsmB1Free _ ->
            l1

        ChangeVectorType _ ->
            l1

        ChangeNotes nts ->
            { l1 | notes = Just nts }

        ChangeReaseDigest rease ->
            { l1 | reaseDigest = Just rease }

        ChangeGB content ->
            { l1 | genbankContent = Just content }

        AppendInsert newInsert ->
            if not (List.member newInsert.bsa1Overhang (List.map .bsa1Overhang <| getInsertsFromLevel1 (Just l1))) then
                { l1 | inserts = List.append l1.inserts [ newInsert ] }

            else
                { l1
                    | inserts =
                        newInsert
                            :: List.filter
                                (\l0 ->
                                    l0.bsa1Overhang /= newInsert.bsa1Overhang
                                )
                                l1.inserts
                }

        AppendBackbone newBackbone ->
            { l1 | backbone = Just newBackbone }

        ResetInsertList ->
            { l1 | inserts = [] }

        ResetAll ->
            { l1 | inserts = [], backbone = Nothing }


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


getInsertsFromLevel1 : Maybe Level1 -> List Level0
getInsertsFromLevel1 level1 =
    case level1 of
        Just l1 ->
            l1.inserts

        Nothing ->
            []


getBackboneFromLevel1 : Maybe Level1 -> Backbone
getBackboneFromLevel1 level1 =
    case level1 of
        Just l1 ->
            Maybe.withDefault initBackbone l1.backbone

        Nothing ->
            initBackbone



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
    Decode.succeed Level1
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
        |> JDP.optional "reaseDigest" (Decode.maybe Decode.string) Nothing
        |> JDP.required "children" (Decode.list level0Decoder)
        |> JDP.optional "backbone" (Decode.maybe backboneDecoder) Nothing
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
          , Encode.string <|
                Maybe.withDefault "" backbone.bacterialStrain
          )
        , ( "responsible", Encode.string <| backbone.responsible )
        , ( "group", Encode.string <| backbone.group )
        , ( "selection"
          , Encode.string <|
                Maybe.withDefault "" backbone.selection
          )
        , ( "cloning_technique"
          , Encode.string <|
                Maybe.withDefault "" backbone.cloningTechnique
          )
        , ( "is_BsmB1_free"
          , Encode.null
          )
        , ( "notes"
          , Encode.string <|
                Maybe.withDefault "" backbone.notes
          )
        , ( "REase_digest"
          , Encode.string <|
                Maybe.withDefault "" backbone.reaseDigest
          )
        , ( "date"
          , Encode.string <|
                Maybe.withDefault "" backbone.date
          )
        , ( "vector_type"
          , Encode.string <|
                Maybe.withDefault "" backbone.vectorType
          )
        , ( "genbank_content"
          , Encode.string <|
                Maybe.withDefault "" backbone.genbankContent
          )
        , ( "level"
          , Encode.int 1
          )
        ]


level0Encoder : Level0 -> Encode.Value
level0Encoder level0 =
    Encode.object
        [ ( "name", Encode.string level0.name )
        , ( "location", Encode.int level0.location )
        , ( "bsa1_overhang"
          , Encode.string <|
                showBsa1Overhang <|
                    level0.bsa1Overhang
          )
        , ( "bacterial_strain"
          , Encode.string <|
                Maybe.withDefault "" level0.bacterialStrain
          )
        , ( "responsible", Encode.string <| level0.responsible )
        , ( "group", Encode.string <| level0.group )
        , ( "selection"
          , Encode.string <|
                Maybe.withDefault "" level0.selection
          )
        , ( "cloning_technique"
          , Encode.string <|
                Maybe.withDefault "" level0.cloningTechnique
          )
        , ( "is_BsmB1_free"
          , Encode.string <|
                isBsmb1FreeToString level0.isBsmb1Free
          )
        , ( "notes"
          , Encode.string <|
                Maybe.withDefault "" level0.notes
          )
        , ( "REase_digest"
          , Encode.string <|
                Maybe.withDefault "" level0.reaseDigest
          )
        , ( "date"
          , Encode.string <|
                Maybe.withDefault "" level0.date
          )
        , ( "genbank_content"
          , Encode.string <|
                Maybe.withDefault "" level0.genbankContent
          )
        , ( "level"
          , Encode.int 2
          )
        ]


levelNEncoder : Level1 -> Encode.Value
levelNEncoder level1 =
    Encode.object
        [ ( "name", Encode.string level1.name )
        , ( "location", Encode.int level1.location )
        , ( "bsmb1_overhang"
          , Maybe.map (showBsmb1Overhang >> Encode.string) level1.bsmb1Overhang
                |> Maybe.withDefault Encode.null
          )
        , ( "responsible", Encode.string <| level1.responsible )
        , ( "group", Encode.string <| level1.group )
        , ( "notes", Encode.string <| Maybe.withDefault "" level1.notes )
        , ( "sequenceLength", Encode.int level1.sequenceLength )
        , ( "REase_digest"
          , Encode.string <|
                Maybe.withDefault "" level1.reaseDigest
          )
        , ( "date"
          , Encode.string <|
                Maybe.withDefault "" level1.date
          )
        , ( "genbank_content", Encode.string <| Maybe.withDefault "" level1.genbankContent )
        , ( "level"
          , Encode.int 3
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


isBsmb1FreeToString : Maybe Bool -> String
isBsmb1FreeToString answer =
    case answer of
        Just True ->
            "YES"

        Just False ->
            "NO"

        Nothing ->
            "NOT TESTED!"
