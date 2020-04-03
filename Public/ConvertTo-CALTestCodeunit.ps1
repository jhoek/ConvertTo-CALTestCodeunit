using namespace ATDD.TestScriptor

function ConvertTo-CALTestCodeunit 
{
    param
    (
        [Parameter(Mandatory, Position = 0)]
        [ValidateRange(1, [int]::MaxValue)]
        [int]$CodeunitID,

        [Parameter(Mandatory, Position = 1)]
        [ValidateLength(1, 30)]
        [string]$CodeunitName,

        [Parameter(ValueFromPipeline)]
        [ValidateNotNull()]
        [TestFeature[]]$Feature = @(),

        [switch]$InitializeFunction,
        [switch]$DoNotAddErrorToHelperFunctions,

        [ValidateNotNullOrEmpty()]
        [string]$GivenFunctionName = '{0}',

        [ValidateNotNullOrEmpty()]
        [string]$WhenFunctionName = '{0}',

        [ValidateNotNullOrEmpty()]        
        [string]$ThenFunctionName = '{0}',

        [ValidateNotNull()]
        [string]$BannerFormat = '// Generated on {0} at {1} by {2}'
    )
    begin
    {
        # Warn about missing placeholder in function name formats
        $GivenFunctionName, $WhenFunctionName, $ThenFunctionName `
        | Where-Object { $_ -notlike '*{0}*' } `
        | ForEach-Object { Write-Warning ('Function name format ''{0}'' does not contain placeholder ''{{0}}''' -f $_) }

    # Prepare scenario cache
    $ScenarioCache = New-Object -TypeName 'System.Collections.Generic.List[TestScenario]'
}

process
{
    # Cache scenarios from incoming features
    $Feature.ForEach{ $ScenarioCache.AddRange($_.Scenarios) }
}

end
{
    function Get-SanitizedName
    {
        param
        (
            [Parameter(Mandatory)]
            [string]$Name
        )

        $Name -split '\W' `
        | Where-Object { $_ } `
        | ForEach-Object { $_ -replace '^(.)', { $_.Groups[1].Value.ToUpperInvariant() } }
        | Join-String 
}

function Get-ElementFunctionName 
{
    param
    (
        [Parameter(Mandatory)]
        [ATDD.TestScriptor.TestScenarioElement]$Element
    )

    switch ($true)
    {
        ($Element -is [Given]) { Get-SanitizedName -Name ($GivenFunctionName -f $Element.Value) }
        ($Element -is [When]) { Get-SanitizedName -Name ($WhenFunctionName -f $Element.Value) }
        ($Element -is [Then]) { Get-SanitizedName -Name ($ThenFunctionName -f $Element.Value) }
        default { Get-SanitizedName -Name $Element.Value }
    }
}

$Now = Get-Date
$Banner = $BannerFormat -f $Now.ToShortDateString(), $Now.ToShortTimeString(), [System.Environment]::UserName
$UniqueFeatureNames = $ScenarioCache | ForEach-Object { $_.Feature.ToString() } | Select-Object -Unique

$ElementFunctionNames = @{ }

$ScenarioCache `
| Select-Object -ExpandProperty Elements `
| ForEach-Object { 
    $CurrentElement = $_
    $ElementFunctionName = Get-ElementFunctionName -Element $CurrentElement
    $ElementFunctionNames.Add($CurrentElement, $ElementFunctionName )
}

Codeunit $CodeunitID $CodeunitName -SubType Test `
    -OnRun { $UniqueFeatureNames | ForEach-Object { "// $_ " } } `
    -SubObjects {
    if ($Banner) { $Banner }

    $ScenarioCache `
    | ForEach-Object {
        $CurrentScenario = $_
        $TestFunctionName = Get-SanitizedName -Name $CurrentScenario.Name

        TestFunction $TestFunctionName -TestFunctionType Test {
            "// $($CurrentScenario.Feature)"
            "// $($CurrentScenario)"

            if ($InitializeFunction) { 'Initialize();' }

            [Given], [When], [Then], [Cleanup] `
            | ForEach-Object {
                $CurrentType = $_
                $CurrentScenario.Elements | Where-Object { $_ -is $CurrentType } | ForEach-Object { $_.GetType().Name } 
            }
    }
}

if ($InitializeFunction)
{
    BooleanVariable Initialized

    Procedure Initialize -Local {
        CodeunitVariable LibraryTestInitialize -SubType 132250
        'LibraryTextInitialize.OnTestInitialize(Codeunit::"{0}");' -f $CodeunitName
        ''
        'if Initialized then'
        '  exit;'
        ''
        'LibraryTestInitialize.OnBeforeTestSuiteInitialize(Codeunit::"{0}");' -f $CodeunitName
        ''
        'IsInitialized := true;'
        'Commit;'
        ''
        'LibraryTestInitialize.OnAfterTestSuiteinitialize(Codeunit::"{0}");' -f $CodeunitName
    }
}
}
}
}

Feature 'Foo' {
    Scenario 1 'Baz' {
        Given 'MyFirstGiven'
        Given 'MySecondGiven'
        When 'MyWhen'
        Then 'MyFirstThen'
        Then 'MySecondThen'
    }

    Scenario 2 'Bar' {
        Given 'MyFirstGiven'
        Given 'MyOtherGiven'
        When 'MyOtherWhen'
        Then 'MyFirstOtherThen'
    }
} | ConvertTo-CALTestCodeunit 50000 'My Test Codeunit' -InitializeFunction