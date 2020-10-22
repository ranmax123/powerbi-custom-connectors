// This file contains your Data Connector logic
[version = "1.0.4"]
section HubSpot;

baseUrl = "https://api.hubapi.com";

accountsSuffixUrl = "/companies/v2/companies/paged";
dealsSuffixUrl = "/deals/v1/deal/paged";

contactsSuffixUrl = "/contacts/v1/lists/all/contacts/all";
ticketsSuffixUrl = "/crm-objects/v1/objects/tickets/paged";
ownersSuffixUrl = "/owners/v2/owners";

accountsProperties = "name,city,country,industry,hubspot_owner_id,website,annualrevenue,createdate,hs_lead_status,num_contacted_notes,recent_deal_amount,total_revenue";

dealsProperties = "age,amount,amount_in_home_currency,closedate,createdate,dealname,dealstage,dealtype,pipeline,hubspot_owner_id,num_notes,num_contacted_notes,closed_lost_reason,closed_won_reason";

contactsProperties = "gender,industry,email,hs_linkedinid,city,country,state,jobtitle,job_function,num_associated_deals,hubspot_owner_id,website,firstname,lastname,phone,hs_lead_status,associatedcompanyid";

ticketProperties = 
"subject,time_to_close,time_to_first_agent_reply,hs_pipeline_stage,hs_createdate,hubspot_owner_id,hs_ticket_category,closed_date,hs_lastcontacted";

contactMaxRows = "100";
defaultMaxRows = "250";
defaultOffset = "0";

[DataSource.Kind="HubSpot", Publish="HubSpot.Publish"]
// shared HubSpot.Contents = () =>
//     let
//         source = HubSpot.GetDeals()
//     in
//         source;


shared HubSpot.Contents = Value.ReplaceType(HubSpot.NavImpl, HubSpot.NavImplType);

HubSpot.NavImplType = type function() as table
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
        _url = url & "&offset=" & Text.From(offset),
        response =  Json.Document(Web.Contents(_url, [ ManualCredentials = true ]))
    in
        response;

//get data
HubSpot.GetPagedData = (url) =>
    let
        jobsJsonPaginated = List.Generate( () => 
                        [pageResult = null, nextOffset = 0, counter = 1],
                        each [counter] <= 1 or [nextOffset] <> 0,
                        each [pageResult = try HubSpot.GetDataPerPage(url, [nextOffset])                                                                         otherwise null, 
                                nextOffset = try pageResult[offset] otherwise 0,
                                counter = [counter] + 1],
                        each [pageResult]),
        
        jobsJsonPaginated2 = List.Skip(jobsJsonPaginated, 1)
    in 
        jobsJsonPaginated2;

//get all accounts data and transform
HubSpot.GetAccountsImpl = () =>

    let
        apiKey = Extension.CurrentCredential()[Key],

        queryRecord = [
        hapikey = apiKey,
        limit = defaultMaxRows
        ],

        queryString = Uri.BuildQueryString(queryRecord),
        propertiesQString = "&properties=" & Text.Replace(accountsProperties, ",", "&properties="),

        url = baseUrl & accountsSuffixUrl & "?" & queryString & propertiesQString,

        Source = HubSpot.GetPagedData (url),
        table = Table.FromList(Source, Splitter.SplitByNothing(), null, null, ExtraValues.Error),

        #"Expanded Column1" = Table.ExpandRecordColumn(table, "Column1", {"companies"}, {"companies"}),
        #"Expanded companies" = Table.ExpandListColumn(#"Expanded Column1", "companies"),
        #"Expanded companies1" = Table.ExpandRecordColumn( #"Expanded companies", "companies", {"portalId", "companyId", "isDeleted", "properties", "additionalDomains", "stateChanges", "mergeAudits"}, {"portalId", "companyId", "isDeleted", "properties", "additionalDomains", "stateChanges", "mergeAudits"}),
        #"Expanded properties1" = Table.ExpandRecordColumn(#"Expanded companies1", "properties", 
            {"country", "name", "industry", "website", "hubspot_owner_id", "city","annualrevenue","createdate","hs_lead_status","num_contacted_notes","recent_deal_amount","total_revenue"}),
        #"Expanded country" = Table.ExpandRecordColumn(#"Expanded properties1", "country", {"value"}, {"country"}),
        #"Expanded name" = Table.ExpandRecordColumn(#"Expanded country", "name", {"value"}, {"name"}),
        #"Expanded industry" = Table.ExpandRecordColumn(#"Expanded name", "industry", {"value"}, {"industry"}),
        #"Expanded website" = Table.ExpandRecordColumn( #"Expanded industry", "website", {"value"}, {"website"}),
        #"Expanded annualrevenue" = Table.ExpandRecordColumn(#"Expanded website", "annualrevenue", {"value"}, {"annualrevenue"}),
        #"Expanded createdate" = Table.ExpandRecordColumn(#"Expanded annualrevenue", "createdate", {"value"}, {"createdate_ts"}),
        
        #"Expanded hubspot_owner_id" = Table.ExpandRecordColumn(#"Expanded createdate", "hubspot_owner_id", {"value"}, {"hubspot_owner_id"}),

        #"Expanded hs_lead_status" = Table.ExpandRecordColumn(#"Expanded hubspot_owner_id", "hs_lead_status", {"value"}, {"hs_lead_status"}),
        #"Expanded num_contacted_notes" = Table.ExpandRecordColumn(#"Expanded hs_lead_status", "num_contacted_notes", {"value"}, {"num_contacted_notes"}),
        #"Expanded recent_deal_amount" = Table.ExpandRecordColumn(#"Expanded num_contacted_notes", "recent_deal_amount", {"value"}, {"recent_deal_amount"}),
        #"Expanded total_revenue" = Table.ExpandRecordColumn(#"Expanded recent_deal_amount", "total_revenue", {"value"}, {"total_revenue"}),

        #"Changed Date Type" = Table.AddColumn( #"Expanded total_revenue", "createdate", each FromTimestampToDate([createdate_ts])),
       // #"Changed Type" = Table.TransformColumnTypes( #"Changed Date Type" ,{{"annualrevenue", Currency.Type},
        //{"recent_deal_amount", Currency.Type},{"total_revenue", Currency.Type}}),
        
        #"Removed Columns" = Table.RemoveColumns( #"Changed Date Type" ,{"additionalDomains", "stateChanges", "mergeAudits","portalId"}),
        #"Final Table" = Table.Distinct(#"Removed Columns")
    in
       #"Final Table";


[DataSource.Kind="HubSpot"]
shared HubSpot.GetDeals = Value.ReplaceType(HubSpot.GetDealsImpl, HubSpot.GetDealsImplType);
HubSpot.GetDealsImplType = type function() as table
        meta [
            Documentation.Name = Extension.LoadString("HubSpot.GetDeals.Name"),
            Documentation.LongDescription = Extension.LoadString("HubSpot.GetDeals.LongDescription")
        ];

HubSpot.GetDealsImpl = () =>

     let
        apiKey = Extension.CurrentCredential()[Key],

        queryRecord = [
        hapikey = apiKey,
        limit = defaultMaxRows,
        includeAssociations="true"
        ],

        queryString = Uri.BuildQueryString(queryRecord),
        propertiesQString = "&properties=" & Text.Replace(dealsProperties, ",", "&properties="),

        url = baseUrl & dealsSuffixUrl & "?" & queryString & propertiesQString,

        Source = HubSpot.GetPagedData (url),
        table = Table.FromList(Source, Splitter.SplitByNothing(), null, null, ExtraValues.Error),

        #"Expanded Column1" = Table.ExpandRecordColumn(table, "Column1", {"deals"}, {"deals"}),
        #"Expanded deals" = Table.ExpandListColumn(#"Expanded Column1", "deals"),

        #"Expanded deals1" = Table.ExpandRecordColumn(#"Expanded deals", "deals", {"portalId", "dealId", "isDeleted", "associations", "properties", "imports", "stateChanges"}, {"portalId", "dealId", "isDeleted", "associations", "properties", "imports", "stateChanges"}),
        DealPropertyAsList = Text.Split(dealsProperties, ","),
         #"Expanded properties" = Table.ExpandRecordColumn(#"Expanded deals1", "properties", DealPropertyAsList),
        #"Expanded pipeline" = Table.ExpandRecordColumn(#"Expanded properties", "pipeline", {"value"}, {"pipeline"}),
        #"Expanded dealname" = Table.ExpandRecordColumn(#"Expanded pipeline", "dealname", {"value"}, {"dealname"}),
        #"Expanded amount" = Table.ExpandRecordColumn(#"Expanded dealname", "amount", {"value"}, {"amount"}),
        #"Expanded closedate" = Table.ExpandRecordColumn(#"Expanded amount", "closedate", {"value"}, {"closedate_ts"}),
        #"Expanded dealstage" = Table.ExpandRecordColumn(#"Expanded closedate", "dealstage", {"value"}, {"dealstage"}),
         #"Expanded dealtype" = Table.ExpandRecordColumn(#"Expanded dealstage", "dealtype", {"value"}, {"dealtype"}),
          #"Expanded owner" = Table.ExpandRecordColumn(#"Expanded dealtype", "hubspot_owner_id", {"value"}, {"hubspot_owner_id"}),

        #"Expanded createdate" = Table.ExpandRecordColumn(#"Expanded owner", "createdate", {"value"}, {"createdate_ts"}),
        #"Expanded amount_in_home_currency" = Table.ExpandRecordColumn(#"Expanded createdate", "amount_in_home_currency", {"value"}, {"amount_in_home_currency"}),
        #"Expanded age" = Table.ExpandRecordColumn(#"Expanded amount_in_home_currency", "age", {"value"}, {"age"}),

       //associations
         #"Expanded associations" = Table.ExpandRecordColumn(#"Expanded age" , "associations", {"associatedCompanyIds"}, {"associatedCompanyIds"}),

         #"Associations" = Table.ExpandListColumn( #"Expanded associations", "associatedCompanyIds"),

         #"CompanyNameChange" = Table.RenameColumns(#"Associations", {{"associatedCompanyIds", "companyId"}}),

        #"Changed Type" = Table.TransformColumnTypes( #"CompanyNameChange",
        {{"age", Int64.Type}, {"amount_in_home_currency", Currency.Type}, {"amount", Currency.Type}}),

        #"Removed Columns" = Table.RemoveColumns(#"Changed Type", {"portalId", "imports", "stateChanges"}),
       
        #"Invoked Custom Function1" = Table.AddColumn( #"Removed Columns", "createdate", each FromTimestampToDate([createdate_ts])),
    
        #"Invoked Custom Function2" = Table.AddColumn(#"Invoked Custom Function1" , "closedate", each FromTimestampToDate([closedate_ts]))
       
    in
         #"Invoked Custom Function2";

//get date one page
HubSpot.GetContactsDataPerPage = (url, offset) =>
     let
        _url = url & "&vidOffset=" & Text.From(offset),
        response =  Json.Document(Web.Contents(_url, [ ManualCredentials = true ]))
    in
        response;

//get data
HubSpot.GetContactsPagedData = (url) =>
    let
        jobsJsonPaginated = List.Generate( () => 
                        [pageResult = null, nextOffset = 0, counter = 1],
                        each [counter] <= 1 or [nextOffset] <> 0,
                        each [pageResult = try HubSpot.GetContactsDataPerPage(url, [nextOffset])                                                                         otherwise null, 
                                nextOffset = try pageResult[#"vid-offset"] otherwise 0,
                                counter = [counter] + 1],
                        each [pageResult]),
        
        jobsJsonPaginated2 = List.Skip(jobsJsonPaginated, 1)
    in 
        jobsJsonPaginated2;

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
        hapikey = apiKey,
        limit = contactMaxRows
        ],

        queryString = Uri.BuildQueryString(queryRecord),
        propertiesQString = "&property=" & Text.Replace(contactsProperties, ",", "&property="),

        url = baseUrl & contactsSuffixUrl & "?" & queryString & propertiesQString,

        Source = HubSpot.GetContactsPagedData (url),

        table = Table.FromList(Source, Splitter.SplitByNothing(), null, null, ExtraValues.Error),

        #"Expanded Column1" = Table.ExpandRecordColumn(table, "Column1", {"contacts"}, {"contacts"}),
        #"Expanded contacts" = Table.ExpandListColumn(#"Expanded Column1", "contacts"),

        #"Expanded contacts2" = Table.ExpandRecordColumn( #"Expanded contacts" , "contacts", {"addedAt", "vid", "canonical-vid", "merged-vids", "portal-id", "is-contact", "profile-token", "profile-url", "properties", "form-submissions", "identity-profiles", "merge-audits"}, {"addedAt", "vid", "canonical-vid", "merged-vids", "portal-id", "is-contact", "profile-token", "profile-url", "properties", "form-submissions", "identity-profiles", "merge-audits"}),
  
         ContactPropertyAsList = Text.Split(contactsProperties, ","),
         
        #"Expanded properties" = Table.ExpandRecordColumn(#"Expanded contacts2", "properties", ContactPropertyAsList),

        #"Expanded website" = Table.ExpandRecordColumn(#"Expanded properties", "website", {"value"}, {"website"}),
        #"Expanded firstname" = Table.ExpandRecordColumn(#"Expanded website", "firstname", {"value"}, {"firstname"}),
        #"Expanded city" = Table.ExpandRecordColumn(#"Expanded firstname", "city", {"value"}, {"city"}),
   
        #"Expanded state" = Table.ExpandRecordColumn(#"Expanded city", "state", {"value"}, {"state"}),
        #"Expanded email" = Table.ExpandRecordColumn(#"Expanded state", "email", {"value"}, {"email"}),
        #"Expanded lastname" = Table.ExpandRecordColumn(#"Expanded email", "lastname", {"value"}, {"lastname"}),

        #"Expanded gender" = Table.ExpandRecordColumn(#"Expanded lastname", "gender", {"value"}, {"gender"}),
        #"Expanded industry" = Table.ExpandRecordColumn(#"Expanded gender", "industry", {"value"}, {"industry"}),
        #"Expanded country" = Table.ExpandRecordColumn(#"Expanded industry", "country", {"value"}, {"country"}),

        #"Expanded jobtitle" = Table.ExpandRecordColumn(#"Expanded country", "jobtitle", {"value"}, {"job_title"}),
        #"Expanded jobfunction" = Table.ExpandRecordColumn(#"Expanded jobtitle", "job_function", {"value"}, {"job_function"}),
        #"Expanded numdeals" = Table.ExpandRecordColumn(#"Expanded jobfunction", "num_associated_deals", {"value"}, {"num_associated_deals"}),
        #"Expanded hubspotownerid" = Table.ExpandRecordColumn(#"Expanded numdeals", "hubspot_owner_id", {"value"}, {"hubspot_owner_id"}),

         #"Expanded phone" = Table.ExpandRecordColumn(#"Expanded hubspotownerid", "phone", {"value"}, {"phone"}),
         
         #"Expanded linkedin" = Table.ExpandRecordColumn(#"Expanded phone", "hs_linkedinid", {"value"}, {"hs_linkedinid"}),
           
         #"Expanded status" = Table.ExpandRecordColumn(#"Expanded linkedin", "hs_lead_status", {"value"}, {"leadstatus"}),

         #"Expanded associated Company" = Table.ExpandRecordColumn(#"Expanded status", "associatedcompanyid", {"value"}, {"companyId"}),


        #"Removed Columns" = Table.RemoveColumns(#"Expanded associated Company" ,{"addedAt", "canonical-vid", "merged-vids", "portal-id", "is-contact", "profile-token", "form-submissions", "identity-profiles", "merge-audits"})

    in
       #"Removed Columns" ;

[DataSource.Kind="HubSpot"]
shared HubSpot.GetTickets = Value.ReplaceType(HubSpot.GetTicketsImpl, HubSpot.GetTicketsImplType);
HubSpot.GetTicketsImplType = type function() as table
        meta [
            Documentation.Name = Extension.LoadString("HubSpot.GetTickets.Name"),
            Documentation.LongDescription = Extension.LoadString("HubSpot.GetTickets.LongDescription")
        ];
HubSpot.GetTicketsImpl = () =>
    let
        apiKey = Extension.CurrentCredential()[Key],

        queryRecord = [
        hapikey = apiKey,
        limit = contactMaxRows
        ],

        queryString = Uri.BuildQueryString(queryRecord),
        propertiesQString = "&properties=" & Text.Replace(ticketProperties, ",", "&properties="),

        url = baseUrl & ticketsSuffixUrl & "?" & queryString & propertiesQString,

        Source = HubSpot.GetPagedData (url),
        #"Converted to Table" = Table.FromList(Source, Splitter.SplitByNothing(), null, null, ExtraValues.Error),
        #"Expanded Column1" = Table.ExpandRecordColumn(#"Converted to Table", "Column1", {"objects", "hasMore", "offset"}, {"objects", "hasMore", "offset"}),
        #"Expanded objects" = Table.ExpandListColumn(#"Expanded Column1", "objects"),
        #"Expanded objects1" = Table.ExpandRecordColumn(#"Expanded objects", "objects", {"objectType", "portalId", "objectId", "properties", "isDeleted"}, {"objectType", "portalId", "objectId", "properties", "isDeleted"}),

         TicketPropertyAsList = Text.Split(ticketProperties, ","),
         #"Expanded properties" = Table.ExpandRecordColumn(#"Expanded objects1", "properties", TicketPropertyAsList),
        #"Expanded subject" = Table.ExpandRecordColumn(#"Expanded properties", "subject", {"value"}, {"subject"}),
        
        #"Expanded time_to_close" = Table.ExpandRecordColumn(#"Expanded subject", "time_to_close", {"value"}, {"time_to_close"}),

        #"Expanded time_to_first_agent_reply" = Table.ExpandRecordColumn(#"Expanded time_to_close", "time_to_first_agent_reply", {"value"}, {"time_to_first_agent_reply"}),

        #"Expanded hs_pipeline_stage" = Table.ExpandRecordColumn(#"Expanded time_to_first_agent_reply", "hs_pipeline_stage", {"value"}, {"hs_pipeline_stage"}),

        #"Expanded hs_createdate" = Table.ExpandRecordColumn(#"Expanded hs_pipeline_stage", "hs_createdate", {"value"}, {"hs_createdate_ts"}),

        #"Expanded hubspot_owner_id" = Table.ExpandRecordColumn(#"Expanded hs_createdate", "hubspot_owner_id", {"value"}, {"hubspot_owner_id"}),

        #"Expanded hs_ticket_category" = Table.ExpandRecordColumn(#"Expanded hubspot_owner_id", "hs_ticket_category", {"value"}, {"hs_ticket_category"}),

        #"Expanded closed_date" = Table.ExpandRecordColumn(#"Expanded hs_ticket_category", "closed_date", {"value"}, {"closed_date_ts"}),

        #"Expanded hs_lastcontacted" = Table.ExpandRecordColumn(#"Expanded closed_date", "hs_lastcontacted", {"value"}, {"hs_lastcontacted_ts"}),
      
        #"Removed Columns" = Table.RemoveColumns(#"Expanded hs_lastcontacted" ,{"objectType", "portalId",
         "isDeleted", "hasMore", "offset"}),

        #"NameChange" = Table.RenameColumns( #"Removed Columns", {{"objectId", "ticketId"}}),

        #"Invoked Custom Function1" = Table.AddColumn( #"NameChange", "hs_createdate", each FromTimestampToDate([hs_createdate_ts])),
    
        #"Invoked Custom Function2" = Table.AddColumn(#"Invoked Custom Function1" , "closed_date", each FromTimestampToDate([closed_date_ts])),

         #"Invoked Custom Function3" = Table.AddColumn(#"Invoked Custom Function2" , "hs_lastcontacted", each FromTimestampToDate([hs_lastcontacted_ts]))

    in
         #"Invoked Custom Function3";

[DataSource.Kind="HubSpot"]
shared HubSpot.GetOwners = Value.ReplaceType(HubSpot.GetOwnersImpl, HubSpot.GetOwnersImplType);

HubSpot.GetOwnersImplType = type function() as table
        meta [
            Documentation.Name = Extension.LoadString("HubSpot.GetOwners.Name"),
            Documentation.LongDescription = Extension.LoadString("HubSpot.GetOwners.LongDescription")
        ];

HubSpot.GetOwnersImpl = () =>
    let
        apiKey = Extension.CurrentCredential()[Key],

        queryRecord = [
        hapikey = apiKey
        ],

        queryString = Uri.BuildQueryString(queryRecord),
        url = baseUrl & ownersSuffixUrl & "?" & queryString,

        Source = Json.Document(Web.Contents(url)),

         #"Converted to Table" = Table.FromList(Source, Splitter.SplitByNothing(), null, null, ExtraValues.Error),
    #"Expanded Column1" = Table.ExpandRecordColumn(#"Converted to Table", "Column1", {"portalId", "ownerId", "type", "firstName", "lastName", "email", "createdAt", "updatedAt", "remoteList", "hasContactsAccess", "isActive", "activeSalesforceId", "userIdIncludingInactive", "activeUserId"}, {"Column1.portalId", "Column1.ownerId", "Column1.type", "Column1.firstName", "Column1.lastName", "Column1.email", "Column1.createdAt", "Column1.updatedAt", "Column1.remoteList", "Column1.hasContactsAccess", "Column1.isActive", "Column1.activeSalesforceId", "Column1.userIdIncludingInactive", "Column1.activeUserId"}),
    #"Renamed Columns" = Table.RenameColumns(#"Expanded Column1",{{"Column1.type", "type"}, {"Column1.firstName", "firstName"}, {"Column1.lastName", "lastName"}, {"Column1.ownerId", "ownerId"}, {"Column1.portalId", "portalId"}, {"Column1.email", "email"}, {"Column1.createdAt", "createdAt_ts"}, {"Column1.updatedAt", "updatedAt_ts"}, {"Column1.isActive", "isActive"}}),
    #"Removed Other Columns" = Table.SelectColumns(#"Renamed Columns",{"portalId", "ownerId", "type", "firstName", "lastName", "email", "createdAt_ts", "updatedAt_ts", "isActive"}),
   
    #"Invoked Custom Function" = Table.AddColumn(#"Removed Other Columns" , "created_at", each FromTimestampToDate([createdAt_ts])),

      #"Invoked Custom Function2" = Table.AddColumn(#"Invoked Custom Function" , "updated_at", each FromTimestampToDate([updatedAt_ts]))

    in
         #"Invoked Custom Function2" ;


// Data Source Kind description
HubSpot = [
    // TestConnection is required to enable the connector through the Gateway
    TestConnection = (dataSourcePath) => { "HubSpot.Contents" },
    Authentication = [
        Key = [KeyLabel = "HubSpot Key (this connector is developed by team at bigintsolutions.com)", Label = "HubSpot Key"]
    ],
    Label = Extension.LoadString("DataSourceLabel")
];


// Data Source UI publishing description
HubSpot.Publish = [
    Beta = true,
    Category = "Online Services",
    ButtonText = { Extension.LoadString("ButtonTitle"), Extension.LoadString("ButtonHelp") },
    LearnMoreUrl = "https://powerbi.microsoft.com/",
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