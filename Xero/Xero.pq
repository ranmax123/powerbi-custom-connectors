// This file contains your Data Connector logic
[version = "1.0.0"]
section Xero;


windowWidth = 1024;
windowHeight = 720;

clientId = Json.Document(Extension.Contents("config.json"))[client_id];
clientSecret = Json.Document(Extension.Contents("config.json"))[client_secret];
callbackUrl = Json.Document(Extension.Contents("config.json"))[redirect_uri];

//Xero token Urls


//Xero API Urls

defaultRowsPerPage = 100;
defaultPageNumber = 1;

[DataSource.Kind="Xero", Publish="Xero.Publish"]
shared Xero.Contents = (optional message as text) =>
    let
        _message = if (message <> null) then message else "(no message)",
        a = "Hello from Xero: " & _message
    in
        a;

// Data Source Kind description
Xero = [
    Authentication = [
       OAuth=
            [StartLogin=Xero.StartLogin, 
            FinishLogin=Xero.FinishLogin,
            Label= Extension.LoadString("Xero.Login")]
    ],
    Label = Extension.LoadString("DataSourceLabel")
];


/* Authentication functions provided by SDK */
Xero.StartLogin = (resourceUrl, state, display) =>
    let
        json = Json.Document(resourceUrl),
        zendeskurl = json[zendeskurl],
        AuthorizeUrl = "https://login.xero.com/identity/connect/authorize" & "?" & Uri.BuildQueryString([
            client_id = clientId,  
            redirect_uri = callbackUrl,
            state = state,
            response_type = "code",
            scope="accounting.transactions.read,accounting.contacts.read,offline_access"
        ])
    in
        [
            LoginUri = AuthorizeUrl,
            CallbackUri = callbackUrl,
            WindowHeight = windowHeight,
            WindowWidth = windowWidth
        ];

Xero.FinishLogin = (context, callbackUri, state) =>
   let
        parts = Uri.Parts(callbackUri)[Query],
        result = if (Record.HasFields(parts, {"error", "error_description"})) then 
                    error Error.Record(parts[error], parts[error_description], parts)
                 else
                    Xero.TokenMethod("authorization_code", "code", parts[code])
    in
        result;

Xero.TokenMethod = (grantType, tokenField, code) =>
    let
        queryString = [
            client_id = clientId,
            client_secret = clientSecret,
            grant_type = grantType,
            redirect_uri = callbackUrl,
            scope="read"
        ],
        queryWithCode = Record.AddField(queryString, tokenField, code),
        
        token_uri = "https://identity.xero.com/connect/token",

        tokenResponse = Web.Contents(token_uri, [
            Content = Text.ToBinary(Uri.BuildQueryString(queryWithCode)),
            Headers = [
                #"Content-type" = "application/x-www-form-urlencoded",
                #"Accept" = "application/json"
            ],
            ManualStatusHandling = {400} 
        ]),
        body = Json.Document(tokenResponse),
        result = if (Record.HasFields(body, {"error", "error_description"})) then 
                    error Error.Record(body[error], body[error_description], body)
                 else
                    body
    in
        result;

// Data Source UI publishing description
Xero.Publish = [
    Beta = true,
    Category = "Online Services",
    ButtonText = { Extension.LoadString("ButtonTitle"), Extension.LoadString("ButtonHelp") },
    LearnMoreUrl = "https://powerbi.microsoft.com/",
    SourceImage = Xero.Icons,
    SourceTypeImage = Xero.Icons
];

Xero.Icons = [
    Icon16 = { Extension.Contents("Xero16.png"), Extension.Contents("Xero20.png"), Extension.Contents("Xero24.png"), Extension.Contents("Xero32.png") },
    Icon32 = { Extension.Contents("Xero32.png"), Extension.Contents("Xero40.png"), Extension.Contents("Xero48.png"), Extension.Contents("Xero64.png") }
];


// Navigation Table Helper
Xero.ToNavigationTable =
(
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
            Preview.DelayColumn = dataColumn, 
            NavigationTable.IsLeafColumn = isLeafColumn
        ],
        navigationTable = Value.ReplaceType(table, newTableType)
    in
        navigationTable;