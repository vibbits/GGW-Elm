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


{-| Vector that accept one or more donorvector. Also called a destination vector.
-}
type alias Backbone =
    { name : String
    , location : Int
    , bsa1Overhang : Maybe Bsa1Overhang
    , bsmb1Overhang : Maybe Bsmb1Overhang
    , sequence : String
    , bacterialStrain : Maybe String
    , responsible : String -- Owner of the Level 0 element = User that adds the vector.
    , group : String
    , selection : Maybe String
    , cloningTechnique : Maybe String
    , notes : Maybe String
    , reaseDigest : Maybe String
    , date : Maybe String
    , vectorType : Maybe String
    , vectorLevel : String
    }


{-| Type of donor vector which are used to construct a Level 1 Vector.
-}
type alias Level0 =
    { name : String
    , location : Int
    , bsa1Overhang : Bsa1Overhang
    , sequence : String
    , bacterialStrain : Maybe String
    , responsible : String -- Owner of the Level 0 element = User that adds the vector.
    , group : String
    , selection : Maybe String
    , cloningTechnique : Maybe String
    , isBsmb1Free : Maybe Bool
    , notes : Maybe String
    , reaseDigest : Maybe String
    , date : Maybe String
    , vectorLevel : String
    }


{-| Type of vector constructed by combining
a Backbone with one or multiple Level 0 verctors.
-}
type alias Level1 =
    { name : String
    , location : Int
    , bsmb1Overhang : Maybe Bsmb1Overhang
    , responsible : String
    , notes : Maybe String
    , sequence : String
    , inserts : List Level0
    , backbone : Maybe Backbone
    , vectorLevel : String
    }


initLevel1 : Level1
initLevel1 =
    { name = ""
    , location = 1
    , bsmb1Overhang = Nothing
    , responsible = ""
    , notes = Just ""
    , sequence = ""
    , inserts = []
    , backbone = Nothing
    , vectorLevel = "LEVEL1" -- Hardcoded!
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
    | ChangeReaseDigest String
    | ChangeVectorType String


initLevel0 : Level0
initLevel0 =
    { name = ""
    , location = 0
    , bsa1Overhang = A__B
    , sequence = ""
    , bacterialStrain = Nothing
    , responsible = "" -- Owner of the Level 0 element = User that adds the vector.
    , group = ""
    , selection = Nothing
    , cloningTechnique = Nothing
    , isBsmb1Free = Just False
    , notes = Nothing
    , reaseDigest = Nothing
    , date = Nothing
    , vectorLevel = "LEVEL0" -- Hardcoded!
    }


initBackbone : Backbone
initBackbone =
    { name = ""
    , location = 0
    , bsa1Overhang = Nothing
    , bsmb1Overhang = Nothing
    , sequence = ""
    , bacterialStrain = Nothing
    , responsible = "" -- Owner of the Level 0 element = User that adds the vector.
    , group = ""
    , selection = Nothing
    , cloningTechnique = Nothing
    , notes = Nothing
    , reaseDigest = Nothing
    , date = Nothing
    , vectorType = Nothing
    , vectorLevel = "BACKBONE" -- Hardcoded!
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

        ChangeResponsible resp ->
            { bb | responsible = resp }

        ChangeGroup grp ->
            { bb | group = grp }

        ChangeSelection sel ->
            { bb | selection = Just sel }

        ChangeBsmb1 bo ->
            { bb | bsmb1Overhang = Just bo }

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

        ChangeCloningTechnique cloningTech ->
            { bb | cloningTechnique = Just cloningTech }

        ChangeIsBsmB1Free _ ->
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

        ChangeNotes nts ->
            { l0 | notes = Just nts }

        ChangeReaseDigest rease ->
            { l0 | reaseDigest = Just rease }

        ChangeBsmb1 _ ->
            l0

        ChangeVectorType _ ->
            l0


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


allOverhangs : List Bsa1Overhang
allOverhangs =
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
        |> JDP.required "sequence" Decode.string
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
        |> JDP.hardcoded "LEVEL0"


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
        |> JDP.required "sequence" Decode.string
        |> JDP.optional "bacterial_strain" (Decode.maybe Decode.string) Nothing
        |> JDP.required "responsible" Decode.string
        |> JDP.required "group" Decode.string
        |> JDP.optional "selection" (Decode.maybe Decode.string) Nothing
        |> JDP.optional "cloning_technique" (Decode.maybe Decode.string) Nothing
        |> JDP.optional "notes" (Decode.maybe Decode.string) Nothing
        |> JDP.optional "reaseDigest" (Decode.maybe Decode.string) Nothing
        |> JDP.optional "date" (Decode.maybe Decode.string) Nothing
        |> JDP.optional "vector_type" (Decode.maybe Decode.string) Nothing
        |> JDP.hardcoded "BACKBONE"


level1Decoder : Decode.Decoder Level1
level1Decoder =
    Decode.succeed Level1
        |> JDP.required "name" Decode.string
        |> JDP.required "location" Decode.int
        |> JDP.optional "bsmb1_overhang"
            (Decode.string
                |> Decode.map (String.trim >> parseBsmb1Overhang)
            )
            Nothing
        |> JDP.required "responsible" Decode.string
        |> JDP.optional "notes" (Decode.maybe Decode.string) Nothing
        |> JDP.required "sequence" Decode.string
        |> JDP.required "children" (Decode.list level0Decoder)
        |> JDP.optional "backbone" (Decode.maybe backboneDecoder) Nothing
        -- TODO: This should be properly decoded
        |> JDP.hardcoded "LEVEL1"


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
