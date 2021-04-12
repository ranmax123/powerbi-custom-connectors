// This file contains your Data Connector logic
section Xero;

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
        // Key = [],
        // UsernamePassword = [],
        // Windows = [],
        Implicit = []
    ],
    Label = Extension.LoadString("DataSourceLabel")
];

// Data Source UI publishing description
Xero.Publish = [
    Beta = true,
    Category = "Other",
    ButtonText = { Extension.LoadString("ButtonTitle"), Extension.LoadString("ButtonHelp") },
    LearnMoreUrl = "https://powerbi.microsoft.com/",
    SourceImage = Xero.Icons,
    SourceTypeImage = Xero.Icons
];

Xero.Icons = [
    Icon16 = { Extension.Contents("Xero16.png"), Extension.Contents("Xero20.png"), Extension.Contents("Xero24.png"), Extension.Contents("Xero32.png") },
    Icon32 = { Extension.Contents("Xero32.png"), Extension.Contents("Xero40.png"), Extension.Contents("Xero48.png"), Extension.Contents("Xero64.png") }
];
