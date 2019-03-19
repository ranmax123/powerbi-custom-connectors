// This file contains your Data Connector logic

[version = "1.0.0"]
section ZendeskSupport;

windowWidth = 1024;
windowHeight = 720;

clientId = Json.Document(Extension.Contents("config.json"))[client_id];
clientSecret = Json.Document(Extension.Contents("config.json"))[client_secret];
callbackUrl = Json.Document(Extension.Contents("config.json"))[redirect_uri];

//Zendesk token Urls
requestTokenUrl = "/oauth/tokens";
authenticateUrl = "/oauth/authorizations/new";

//Zendesk API Urls

listAllViewsUrl = "/api/v2/views.json";
viewTicketsPrefixUrl = "/api/v2/views/";
viewTicketsSuffixUrl = "/tickets.json";

defaultRowsPerPage = 100;
defaultPageNumber = 1;

[DataSource.Kind="ZendeskSupport", Publish="ZendeskSupport.Publish"]
shared ZendeskSupport.Contents = Value.ReplaceType(ZendeskSupport.NavImpl, ZendeskSupport.NavImplType);

ZendeskSupport.NavImplType = type function(
        zendeskurl as (type text meta [
        Documentation.FieldCaption = "Zendesk URL (https://{subdomain}.zendesk.com)",
        Documentation.FieldDescription = "Zendesk URL",
        Documentation.SampleValues = {"https://{subdomain}.zendesk.com"}
        ])

        ) as table
        meta [
            Documentation.Name = Extension.LoadString("ZendeskSupport.Contents.Name"),
            Documentation.LongDescription = Extension.LoadString("ZendeskSupport.Contents.LongDescription")
        ];

ZendeskSupport.NavImpl =  (zendeskurl) as any =>
    let
        table = ZendeskSupport.GetViews(zendeskurl)
    in
        table;


// [DataSource.Kind="ZendeskSupport", Publish="ZendeskSupport.Publish"]
// shared ZendeskSupport.Contents = (optional message as text) =>
//     let
//         a = ZendeskSupport.GetTickets(360086417151)
//     in
//         a;
// 

ZendeskSupport.GetViews = (zendeskurl) =>
    let
        _url = zendeskurl & listAllViewsUrl & "?per_page=" &  Text.From(defaultRowsPerPage) & "&active=true",
        source = ZendeskSupport.GetPagedData(_url, {}, "views"),
     
        rtable = PagesToNavTabler(source, zendeskurl)
    in
       rtable;


ZendeskSupport.GetTickets = (viewid, zendeskurl) =>
    let
        _url = zendeskurl & viewTicketsPrefixUrl & Text.From(viewid) & viewTicketsSuffixUrl & "?per_page=" &  Text.From(defaultRowsPerPage),

        source = ZendeskSupport.GetPagedData(_url, {}, "tickets"),
        
        table = Table.FromList(source, Splitter.SplitByNothing(), null, null, ExtraValues.Error),
         
        //CODE FOR HANDLING NO DATA
        tableWithCheck = if Table.IsEmpty(table) then #table(type table[Column1 = {[subject = any, type = any, priority = any, status = any, id = any, external_id = any, created_at = any, updated_at = any, via = any,  raw_subject = any, description = any, recipient = any, requester_id = any, submitter_id = any, assignee_id = any, organization_id = any, group_id = any, collaborator_ids = any, follower_ids = any, email_cc_ids = any, forum_topic_id = any, problem_id = any, has_incidents = any, is_public = any, due_at = any, tags = any, custom_fields = any, satisfaction_rating = any, sharing_agreement_ids = any, fields = any, followup_ids = any, brand_id = any, allow_channelback = any, allow_attachments = any]}], {}) else table,

        #"Expanded tickets1" = Table.ExpandRecordColumn(tableWithCheck, "Column1", {"subject", "type", "priority", "status", "id", "external_id", "created_at", "updated_at", "via",  "raw_subject", "description", "recipient", "requester_id", "submitter_id", "assignee_id", "organization_id", "group_id", "collaborator_ids", "follower_ids", "email_cc_ids", "forum_topic_id", "problem_id", "has_incidents", "is_public", "due_at", "tags", "custom_fields", "satisfaction_rating", "sharing_agreement_ids", "fields", "followup_ids", "brand_id", "allow_channelback", "allow_attachments"})
    in
         #"Expanded tickets1"  ;

         
PagesToNavTabler = (views as list, zendeskurl) =>
    let
        navHeader = {"Name","Key","Data","ItemKind", "ItemName", "IsLeaf"}, 
        navUsers = List.Accumulate(views, {}, 
                            (state, current) => state & 
                            {{current[title], current[id], ZendeskSupport.GetTickets(current[id], zendeskurl), "Table", "Table", true}} ),
        objects = #table(navHeader, navUsers),
        table = ZendeskSupport.ToNavigationTable (objects, {"Key"}, "Name", "Data", "ItemKind", "ItemName", "IsLeaf")
    in
        table;


//code reference taken from https://github.com/mbilling/PBIConnectors/blob/master/Instagram/Instagram.pq      

ZendeskSupport.GetPagedData = (query, result, objectType) =>
    let
        response = Json.Document(Web.Contents(query)),
        newResult = List.Combine({result, if objectType = "views" then response[views] else response[tickets]}),
        nextQuery = try response[next_page] otherwise null,
        testForError = try response
    in
        if testForError[HasError] then 
            {[has_error = testForError[HasError], error_value = try testForError[Value], error_reason = testForError[Error][Reason], error_message = testForError[Error][Message]]}
        else 
            if nextQuery <> null then 
                ZendeskSupport.GetPagedData(nextQuery, newResult, objectType)
            else
                newResult;

/* Authentication functions provided by SDK */
ZendeskSupport.StartLogin = (resourceUrl, state, display) =>
    let
        json = Json.Document(resourceUrl),
        zendeskurl = json[zendeskurl],
        AuthorizeUrl = zendeskurl & authenticateUrl & "?" & Uri.BuildQueryString([
            client_id = clientId,  
            redirect_uri = callbackUrl,
            state = state,
            response_type = "code",
            scope="read"
        ])
    in
        [
            LoginUri = AuthorizeUrl,
            CallbackUri = callbackUrl,
            WindowHeight = windowHeight,
            WindowWidth = windowWidth,
            Context = zendeskurl
        ];

ZendeskSupport.FinishLogin = (context, callbackUri, state) =>
   let
        parts = Uri.Parts(callbackUri)[Query],
        result = if (Record.HasFields(parts, {"error", "error_description"})) then 
                    error Error.Record(parts[error], parts[error_description], parts)
                 else
                    ZendeskSupport.TokenMethod("authorization_code", "code", parts[code], context)
    in
        result;

ZendeskSupport.TokenMethod = (grantType, tokenField, code, zendeskurl) =>
    let
        queryString = [
            client_id = clientId,
            client_secret = clientSecret,
            grant_type = grantType,
            redirect_uri = callbackUrl,
            scope="read"
        ],
        queryWithCode = Record.AddField(queryString, tokenField, code),
        
        token_uri = zendeskurl & requestTokenUrl,

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

// Data Source Kind description
ZendeskSupport = [
    // TestConnection is required to enable the connector through the Gateway
    TestConnection = (dataSourcePath) => 
        let
            json = Json.Document(dataSourcePath),
            zendeskurl = json[zendeskurl]
        in
            { "ZendeskSupport.Contents", zendeskurl},
    Authentication = [
        OAuth=
            [StartLogin=ZendeskSupport.StartLogin, 
            FinishLogin=ZendeskSupport.FinishLogin,
            Label= Extension.LoadString("ZendeskSupport.Login")]
    ],
    Label = Extension.LoadString("DataSourceLabel")
];

// Data Source UI publishing description
ZendeskSupport.Publish = [
    Beta = true,
    Category = "Online Services",
    ButtonText = { Extension.LoadString("ButtonTitle"), Extension.LoadString("ButtonHelp") },
    LearnMoreUrl = "https://powerbi.microsoft.com/",
    SourceImage = ZendeskSupport.Icons,
    SourceTypeImage = ZendeskSupport.Icons
];

ZendeskSupport.Icons = [
    Icon16 = { Extension.Contents("ZendeskSupport16.png"), Extension.Contents("ZendeskSupport20.png"), Extension.Contents("ZendeskSupport24.png"), Extension.Contents("ZendeskSupport32.png") },
    Icon32 = { Extension.Contents("ZendeskSupport32.png"), Extension.Contents("ZendeskSupport40.png"), Extension.Contents("ZendeskSupport48.png"), Extension.Contents("ZendeskSupport64.png") }
];

// Navigation Table Helper
ZendeskSupport.ToNavigationTable =
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