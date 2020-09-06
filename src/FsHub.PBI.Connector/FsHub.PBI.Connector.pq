// This file contains your Data Connector logic
section FsHub;

BaseUrl = "https://fshub.io/api/v3/";
PageSize = 25;

// Data Source UI publishing description
FsHub.Publish = [
    Beta = true,
    Category = "Online Services",
    ButtonText = { "FsHub", "FsHub - virtual pilot and airline flight tracking and performance monitoring" },
    LearnMoreUrl = "https://fshub.io/",
    SourceImage = FsHub.Icons,
    SourceTypeImage = FsHub.Icons
];

FsHub.Icons = [
    Icon16 = { Extension.Contents("FsHub16.png"), Extension.Contents("FsHub20.png"), Extension.Contents("FsHub24.png"), Extension.Contents("FsHub32.png") },
    Icon32 = { Extension.Contents("FsHub32.png"), Extension.Contents("FsHub40.png"), Extension.Contents("FsHub48.png"), Extension.Contents("FsHub64.png") }
];

[DataSource.Kind="FsHub", Publish="FsHub.Publish"]
shared FsHub.Contents =  Value.ReplaceType(FsHubNavTable, type function () as any);

// Common functions
Table.ToNavigationTable = (
    table as table,
    keyColumns as list,
    nameColumn as text,
    dataColumn as text,
    itemKindColumn as text,
    itemNameColumn as text,
    isLeafColumn as text
) as table =>
    let
        tableType = Value.Type(table),
        newTableType = Type.AddTableKey(tableType, keyColumns, true) meta 
        [
            NavigationTable.NameColumn = nameColumn, 
            NavigationTable.DataColumn = dataColumn,
            NavigationTable.ItemKindColumn = itemKindColumn, 
            Preview.DelayColumn = itemNameColumn, 
            NavigationTable.IsLeafColumn = isLeafColumn
        ],
        navigationTable = Value.ReplaceType(table, newTableType)
    in
        navigationTable;

FsHubNavTable = () as table =>
    let
        source = #table({"Name", "Data", "ItemKind", "ItemName", "IsLeaf"}, {
            { "Airlines", GetAirlinesTable(), "Table", "Table", true },
            { "Airports", GetAirportsTable(), "Table", "Table", true },
            { "Flights", GetFlightsTable(), "Table", "Table", true },
            { "Pilots", GetPilotsTable(), "Table", "Table", true }
        }),
        navTable = Table.ToNavigationTable(source, {"Name"}, "Name", "Data", "ItemKind", "ItemName", "IsLeaf")
    in
        navTable;

// Data Source Kind description
FsHub = [
    Authentication = [
        Key = [
            Label = "X-Pilot-Token",
            KeyLabel = "FsHub personal access token"
        ]
    ],
    Label = "FsHub"
];


FsHubImpl = (f as text, optional cursor) as table =>
    let
        token = Extension.CurrentCredential()[Key],
        headers = [
            #"X-Pilot-Token" = token,
            #"Accept" = "application/json",
            #"Content-Type" = "application/json"
        ],
        count = if (cursor is null) then 1 else cursor,
        url = Uri.Combine(BaseUrl, (f & "?limit=" & Text.From(PageSize) & "&cursor=" & Text.From(count))),
        response = Web.Contents(url, [ Headers = headers, ManualCredentials = true ]),
        json = Json.Document(response),
        result = Record.ToTable(json)
    in
        result;

GetAirlinesTable = () as table =>
    let
        source = FsHubImpl("airline"),
        value = source{0}[Value],
        #"Converted to Table" = Table.FromList(value, Splitter.SplitByNothing(), null, null, ExtraValues.Error),
        #"Expanded Column1" = Table.ExpandRecordColumn(#"Converted to Table", "Column1", {"id", "name", "abbr", "owner", "handles", "links"}, {"id", "Name", "Abbr", "owner", "handles", "links"}),
        #"Expanded Column1.owner" = Table.ExpandRecordColumn(#"Expanded Column1", "owner", {"id"}, {"owner.id"}),
        #"Expanded handles" = Table.ExpandRecordColumn(#"Expanded Column1.owner", "handles", {"facebook", "twitter", "website"}, {"Facebook", "Twitter", "Website"}),
        #"Changed Type" = Table.TransformColumnTypes(#"Expanded handles",{{"id", Int64.Type}, {"Name", type text}, {"Abbr", type text}, {"owner.id", Int64.Type}, {"Facebook", type text}, {"Twitter", type text}, {"Website", type text}})
    in
        #"Changed Type";

GetAirportsTable = () as table =>
    let
        source = FsHubImpl("airport/EGSS"),
        value = source[Value],
        airport = Table.FromList(value, Splitter.SplitByNothing(), null, null, ExtraValues.Error),
        #"Expanded Column1" = Table.ExpandRecordColumn(airport, "Column1", {"icao", "iata", "name", "locale", "geo", "alt", "mag_var", "frequencies", "runways", "links"}, {"icao", "iata", "Name", "locale", "geo", "Alt", "mag_var", "Frequencies", "Runways", "Links"}),
        #"Expanded locale" = Table.ExpandRecordColumn(#"Expanded Column1", "locale", {"city", "state", "county"}, {"locale.city", "locale.state", "locale.county"}),
        #"Expanded geo" = Table.ExpandRecordColumn(#"Expanded locale", "geo", {"lat", "lng"}, {"Latitude", "Longitude"}),
        #"Renamed Columns" = Table.RenameColumns(#"Expanded geo",{{"locale.city", "City"}, {"locale.state", "State"}, {"locale.county", "County"}}),
        #"Changed Type" = Table.TransformColumnTypes(#"Renamed Columns",{{"Latitude", type number}, {"Longitude", type number}, {"City", type text}, {"State", type text}, {"County", type text}})
    in
        #"Changed Type";

GetFlightsTable = () as table =>
    let
        source = FsHubImpl("flight")
    in
        source;

GetPilotsTable = () as table =>
    let
        source = FsHubImpl("pilot/2"),
        value = source[Value],
        pilot = Table.FromList(value, Splitter.SplitByNothing(), null, null, ExtraValues.Error),
        #"Expanded Column1" = Table.ExpandRecordColumn(pilot, "Column1", {"id", "name", "bio", "handles", "base", "locale", "gps", "timezone", "country", "online_at", "created_at", "links"}, {"id", "Name", "Bio", "handles", "Base", "Locale", "gps", "Timezone", "Country", "online_at", "created_at", "links"}),
        #"Expanded handles" = Table.ExpandRecordColumn(#"Expanded Column1", "handles", {"facebook", "twitter", "website", "vatsim", "ivao"}, {"Facebook", "Twitter", "Website", "vatsim", "ivao"}),
        #"Expanded gps" = Table.ExpandRecordColumn(#"Expanded handles", "gps", {"lat", "lng"}, {"Latitude", "Longitude"}),
        #"Changed Type" = Table.TransformColumnTypes(#"Expanded gps",{{"id", Int64.Type}, {"Name", type text}, {"Bio", type text}, {"Facebook", type text}, {"Twitter", type text}, {"Website", type text}, {"Base", type text}, {"Locale", type text}, {"Latitude", type number}, {"Longitude", type number}, {"Timezone", type text}, {"Country", type text}, {"online_at", type datetimezone}, {"created_at", type datetimezone}})
    in
        #"Changed Type";
