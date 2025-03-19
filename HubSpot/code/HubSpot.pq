// This file contains your Data Connector logic
[version = "3.0.0"]
section HubSpot;

baseUrl = "https://api.hubapi.com";

accountsSuffixUrl = "/crm/v3/objects/companies";
dealsSuffixUrl = "/crm/v3/objects/deals";

contactsSuffixUrl = "/crm/v3/objects/contacts";
ticketsSuffixUrl = "/crm/v3/objects/tickets";
ownersSuffixUrl = "/crm/v3/owners/";

accountsPropertiesSuffixUrl = "/crm/v3/properties/companies";

accountsProperties = "name,city,country,industry,hubspot_owner_id,website,annualrevenue,createdate,hs_lead_status,num_contacted_notes,recent_deal_amount,total_revenue";

dealsProperties = "hs_forecast_amount,hs_manual_forecast_category,hs_forecast_probability,amount,amount_in_home_currency,closedate,createdate,dealname,dealstage,dealtype,pipeline,hubspot_owner_id,num_notes,num_contacted_notes,closed_lost_reason,closed_won_reason";

contactsProperties = "lead_source,gender,industry,email,hs_linkedinid,city,country,state,jobtitle,job_function,num_associated_deals,hubspot_owner_id,website,firstname,lastname,phone,hs_lead_status,hs_analytics_source,lifecyclestage,associatedcompanyid,createdate";

ticketProperties = 
"hs_ticket_priority,hs_pipeline,subject,time_to_close,time_to_first_agent_reply,hs_pipeline_stage,createdate,source_type,hubspot_owner_id,hs_ticket_category,closed_date,hs_lastcontacted";

ownerProperties = "id,email,type,firstName,lastName,userId,userIdIncludingInactive,createdAt,updatedAt,archived";

contactMaxRows = "100";
defaultMaxRows = "100";
defaultOffset = "0";

 [DataSource.Kind="HubSpot", Publish="HubSpot.Publish"]
// shared HubSpot.Contents = () =>
//     let
//         source = HubSpot.GetDeals()
//     in
//         source;


shared HubSpot.Contents = Value.ReplaceType(HubSpot.NavImpl, HubSpot.Params);

HubSpot.Params = type function() as table
        meta [
            Documentation.Name = Extension.LoadString("HubSpot.Contents.Name"),
            Documentation.LongDescription = Extension.LoadString("HubSpot.Contents.LongDescription")
        ];

HubSpot.NavImpl =  () as table =>
    let
        objects = #table(
            {"Name",       "Key",  "Data", "ItemKind", "ItemName", "IsLeaf"},{
            {"Accounts",   "Accounts",  HubSpot.GetAccounts() , "Table",    "Table",    true},
            {"Contacts",   "Contacts",  HubSpot.GetContacts() , "Table",    "Table",    true},
            {"Deals",   "Deals",  HubSpot.GetDeals() , "Table",    "Table",    true},
            {"Tickets",   "Tickets",  HubSpot.GetTickets() , "Table",    "Table",    true},
            {"Owners",   "Owners",  HubSpot.GetOwners() , "Table",    "Table",    true}
        }),
        NavTable = HubSpot.ToNavigationTable(objects, {"Key"}, "Name", "Data", "ItemKind", "ItemName", "IsLeaf")
    in
        NavTable;



[DataSource.Kind="HubSpot"]
shared HubSpot.GetAccounts = Value.ReplaceType(HubSpot.GetAccountsImpl, HubSpot.GetAccountsImplType);

HubSpot.GetAccountsImplType = type function() as table
        meta [
            Documentation.Name = Extension.LoadString("HubSpot.GetAccounts.Name"),
            Documentation.LongDescription = Extension.LoadString("HubSpot.GetAccounts.LongDescription")
        ];

//get date one page
HubSpot.GetDataPerPage = (url, offset) =>
     let
        _url = url & (if offset <> null then "&after=" & Text.From(offset) else ""),
        accessToken = Extension.CurrentCredential()[Key],
        apiHeaders = [#"Content-Type" = "application/json", Authorization = "Bearer " & accessToken],
        response =  Json.Document(Web.Contents(_url, [ ManualCredentials = true, Headers = apiHeaders]))
    in
        response;

Hubspot.GetAccountCustomProperties = () =>

    let

        queryRecord = [
        archived = "false"
        ],

        queryString = Uri.BuildQueryString(queryRecord),

        url = baseUrl & accountsPropertiesSuffixUrl & "?" & queryString,

        Source = HubSpot.GetDataPerPage (url, null),

        #"Converted to Table" = Table.FromRecords({Source}),
        #"Expanded results" = Table.ExpandListColumn(#"Converted to Table", "results"),
        #"Expanded results1" = Table.ExpandRecordColumn(#"Expanded results", "results", {"updatedAt", "createdAt", "name", "label", "type", "fieldType", "description", "groupName", "options", "createdUserId", "updatedUserId", "referencedObjectType", "displayOrder", "calculated", "externalOptions", "archived", "hasUniqueValue", "hidden", "hubspotDefined", "showCurrencySymbol", "modificationMetadata", "formField"}, {"results.updatedAt", "results.createdAt", "results.name", "results.label", "results.type", "results.fieldType", "results.description", "results.groupName", "results.options", "results.createdUserId", "results.updatedUserId", "results.referencedObjectType", "results.displayOrder", "results.calculated", "results.externalOptions", "results.archived", "results.hasUniqueValue", "results.hidden", "results.hubspotDefined", "results.showCurrencySymbol", "results.modificationMetadata", "results.formField"}),
        #"Expanded results.modificationMetadata" = Table.ExpandRecordColumn(#"Expanded results1", "results.modificationMetadata", {"archivable", "readOnlyDefinition", "readOnlyOptions", "readOnlyValue"}, {"results.modificationMetadata.archivable", "results.modificationMetadata.readOnlyDefinition", "results.modificationMetadata.readOnlyOptions", "results.modificationMetadata.readOnlyValue"}),
        #"Changed Type" = Table.TransformColumnTypes(#"Expanded results.modificationMetadata",{{"results.updatedAt", type datetime}, {"results.createdAt", type datetime}, {"results.name", type text}, {"results.label", type text}, {"results.type", type text}, {"results.fieldType", type text}, {"results.description", type text}, {"results.groupName", type text}, {"results.options", type any}, {"results.createdUserId", Int64.Type}, {"results.updatedUserId", Int64.Type}, {"results.referencedObjectType", type any}, {"results.displayOrder", Int64.Type}, {"results.calculated", type logical}, {"results.externalOptions", type logical}, {"results.archived", type logical}, {"results.hasUniqueValue", type logical}, {"results.hidden", type logical}, {"results.hubspotDefined", type logical}, {"results.showCurrencySymbol", type logical}, {"results.modificationMetadata.archivable", type logical}, {"results.modificationMetadata.readOnlyDefinition", type logical}, {"results.modificationMetadata.readOnlyOptions", type logical}, {"results.modificationMetadata.readOnlyValue", type logical}, {"results.formField", type logical}}),
        CustomProp = Table.SelectRows(#"Changed Type", each ([results.hubspotDefined] = null)),//custom properties
        #"Removed Other Columns" = Table.SelectColumns(CustomProp,{"results.name"}),
        #"results name" = #"Removed Other Columns"[results.name]
    in
     #"results name" ;

//get all accounts data and transform
HubSpot.GetAccountsImpl = () =>

    let

        accountsPropFromHubSpot = Hubspot.GetAccountCustomProperties(),
        definedProp = Text.Split(accountsProperties, ","),
        finalProp = List.Distinct(List.Combine({accountsPropFromHubSpot, definedProp})),
       
       //construct properties string
        propertiesQString = List.Accumulate(finalProp, "", (state, current) => 
                                        if state="" 
                                        then state & "&properties="&current 
                                        else state & "&" & "properties="&current),

        queryRecord = [
        limit = defaultMaxRows
        ],

        queryString = Uri.BuildQueryString(queryRecord),

        url = baseUrl & accountsSuffixUrl & "?" & queryString & propertiesQString,

        Source = HubSpot.GetDataPerPage (url, null),
        table = Table.FromList(Source[results], Splitter.SplitByNothing(), null, null, ExtraValues.Error),
        #"Expanded Column3" = Table.ExpandRecordColumn(table, "Column1", {"id", "properties", "createdAt", "updatedAt", "archived"}, {"id", "properties", "createdAt", "updatedAt", "archived"})
,
        #"Expanded properties" = Table.ExpandRecordColumn(#"Expanded Column3", "properties", finalProp)

        in 
             #"Expanded properties";



[DataSource.Kind="HubSpot"]
shared HubSpot.GetDeals = Value.ReplaceType(HubSpot.GetDealsImpl, HubSpot.GetDealsImplType);
HubSpot.GetDealsImplType = type function() as table
        meta [
            Documentation.Name = Extension.LoadString("HubSpot.GetDeals.Name"),
            Documentation.LongDescription = Extension.LoadString("HubSpot.GetDeals.LongDescription")
        ];

HubSpot.GetDealsImpl = () =>

     let
        queryRecord = [
        limit = defaultMaxRows
        ],

        queryString = Uri.BuildQueryString(queryRecord),
        propertiesQString = "&properties=" & Text.Replace(dealsProperties, ",", "&properties="),

        url = baseUrl & dealsSuffixUrl & "?" & queryString & propertiesQString & "&associations=company&associations=contact",

        Source = HubSpot.GetDataPerPage (url, null),
        #"Converted to Table" = Table.FromRecords({Source}),
        #"Expanded results" = Table.ExpandListColumn(#"Converted to Table", "results"),
        #"Expanded results1" = Table.ExpandRecordColumn(#"Expanded results", "results", {"id", "properties", "createdAt", "updatedAt", "archived", "associations"}, {"id", "properties", "createdAt", "updatedAt", "archived", "associations"}),
       
        DealPropertyAsList = Text.Split(dealsProperties, ","),
        #"Expanded properties" = Table.ExpandRecordColumn(#"Expanded results1", "properties", DealPropertyAsList),

        #"Expanded associations" = Table.ExpandRecordColumn(#"Expanded properties", "associations", {"companies", "contacts"}, {"companies", "contacts" }),
        #"Expanded companies" = Table.ExpandRecordColumn(#"Expanded associations", "companies", {"results"}, {"results"}),
        #"Expanded results2" = Table.ExpandListColumn(#"Expanded companies", "results"),
        #"Expanded results3" = Table.ExpandRecordColumn(#"Expanded results2", "results", {"id"}, {"companyId"}),

         #"Expanded contacts" = Table.ExpandRecordColumn(#"Expanded results3", "contacts", {"results"}, {"results"}),
        #"Expanded contacts2" = Table.ExpandListColumn(#"Expanded contacts", "results"),
        #"Expanded contacts3" = Table.ExpandRecordColumn(#"Expanded contacts2", "results", {"id"}, {"contactId"}),
        
        Uniq = Table.Distinct(#"Expanded contacts3")
    in
        Uniq;


[DataSource.Kind="HubSpot"]
shared HubSpot.GetContacts = Value.ReplaceType(HubSpot.GetContactsImpl, HubSpot.GetContactsImplType);

HubSpot.GetContactsImplType = type function() as table
        meta [
            Documentation.Name = Extension.LoadString("HubSpot.GetContacts.Name"),
            Documentation.LongDescription = Extension.LoadString("HubSpot.GetContacts.LongDescription")
        ];       
HubSpot.GetContactsImpl = () =>
    let
        apiKey = Extension.CurrentCredential()[Key],

        queryRecord = [
        limit = contactMaxRows
        ],

        queryString = Uri.BuildQueryString(queryRecord),
        propertiesQString = "&properties=" & Text.Replace(contactsProperties, ",", "&properties="),

        url = baseUrl & contactsSuffixUrl & "?" & queryString & propertiesQString,

        Source = HubSpot.GetDataPerPage(url, null),
    
        table = Table.FromList(Source[results], Splitter.SplitByNothing(), null, null, ExtraValues.Error),
       
        #"Expanded Column3" = Table.ExpandRecordColumn(table, "Column1", {"id", "properties", "createdAt", "updatedAt", "archived"}, {"id", "properties", "createdAt", "updatedAt", "archived"})
,
        ContactPropertyAsList = Text.Split(contactsProperties, ","),
        #"Expanded properties" = Table.ExpandRecordColumn(#"Expanded Column3", "properties", ContactPropertyAsList)

in 
    #"Expanded properties";
       

[DataSource.Kind="HubSpot"]
shared HubSpot.GetTickets = Value.ReplaceType(HubSpot.GetTicketsImpl, HubSpot.GetTicketsImplType);
HubSpot.GetTicketsImplType = type function() as table
        meta [
            Documentation.Name = Extension.LoadString("HubSpot.GetTickets.Name"),
            Documentation.LongDescription = Extension.LoadString("HubSpot.GetTickets.LongDescription")
        ];
HubSpot.GetTicketsImpl = () =>
    let

        queryRecord = [
        limit = contactMaxRows
        ],

        queryString = Uri.BuildQueryString(queryRecord),
        propertiesQString = "&properties=" & Text.Replace(ticketProperties, ",", "&properties="),

        url = baseUrl & ticketsSuffixUrl & "?" & queryString & propertiesQString,

        Source = HubSpot.GetDataPerPage (url, null),
        table = Table.FromList(Source[results], Splitter.SplitByNothing(), null, null, ExtraValues.Error),
       
        #"Expanded Column3" = Table.ExpandRecordColumn(table, "Column1", {"id", "properties", "createdAt", "updatedAt", "archived"}, {"id", "properties", "createdAt", "updatedAt", "archived"})
,
        TicketPropertyAsList = Text.Split(ticketProperties, ","),
        #"Expanded properties" = Table.ExpandRecordColumn(#"Expanded Column3", "properties", TicketPropertyAsList)

in 
   #"Expanded properties";


[DataSource.Kind="HubSpot"]
shared HubSpot.GetOwners = Value.ReplaceType(HubSpot.GetOwnersImpl, HubSpot.GetOwnersImplType);

HubSpot.GetOwnersImplType = type function() as table
        meta [
            Documentation.Name = Extension.LoadString("HubSpot.GetOwners.Name"),
            Documentation.LongDescription = Extension.LoadString("HubSpot.GetOwners.LongDescription")
        ];

HubSpot.GetOwnersImpl = () =>
    let

        url = baseUrl & ownersSuffixUrl,

        Source = HubSpot.GetDataPerPage(url, null),
      #"Converted to Table" = Table.FromRecords({Source}),
    #"Expanded results" = Table.ExpandListColumn(#"Converted to Table", "results"),

     OwnerPropertyAsList = Text.Split(ownerProperties, ","),
    #"Expanded results1" = Table.ExpandRecordColumn(#"Expanded results", "results",OwnerPropertyAsList,OwnerPropertyAsList) 
   in
   #"Expanded results1";


// Data Source Kind description
HubSpot = [
    // TestConnection is required to enable the connector through the Gateway
    TestConnection = (dataSourcePath) => { "HubSpot.Contents" },
    Authentication = [
        Key = [KeyLabel = "HubSpot Private App Access Token (this connector is developed by Ranbeer Makin)", Label = "HubSpot Access Token"]
    ],
    Label = Extension.LoadString("DataSourceLabel")
];


// Data Source UI publishing description
HubSpot.Publish = [
    Beta = true,
    Category = "Online Services",
    ButtonText = { Extension.LoadString("ButtonTitle"), Extension.LoadString("ButtonHelp") },
    LearnMoreUrl = "https://www.bigintsolutions.com",
    SourceImage = HubSpot.Icons,
    SourceTypeImage = HubSpot.Icons
];

HubSpot.Icons = [
    Icon16 = { Extension.Contents("HubSpotConnector16.png"), Extension.Contents("HubSpotConnector20.png"), Extension.Contents("HubSpotConnector24.png"), Extension.Contents("HubSpotConnector32.png") },
    Icon32 = { Extension.Contents("HubSpotConnector32.png"), Extension.Contents("HubSpotConnector40.png"), Extension.Contents("HubSpotConnector48.png"), Extension.Contents("HubSpotConnector64.png") }
];


 FromTimestampToDate = (timestamp as any) as any =>
    let
        extractedTimestamp = if timestamp <> null and Text.Length(timestamp) > 10 then Text.Range(timestamp, 0, 10) else timestamp,
        timestampToNumber = try Number.From(extractedTimestamp) otherwise null,
        date = if timestampToNumber <> null then #datetime(1970, 1, 1, 0, 0, 0) + #duration(0, 0, 0, timestampToNumber) else null
    in 
       date;


// Navigation Table Helper
HubSpot.ToNavigationTable =
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