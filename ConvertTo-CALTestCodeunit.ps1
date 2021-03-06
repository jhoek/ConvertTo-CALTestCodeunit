#requires -modules Atdd.TestScriptor, UncommonSense.CBreeze.Automation

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

            ($Name -split '\W' `
                | Where-Object { $_ } `
                | ForEach-Object {
                    [regex]::Replace($_, '^.', { param($firstChar)$firstChar.Value.ToUpperInvariant() })
                }) -join ''
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

        # Prepare banner
        $Now = Get-Date
        $Banner = $BannerFormat -f $Now.ToShortDateString(), $Now.ToShortTimeString(), [System.Environment]::UserName

        # Find unique feature names
        $UniqueFeatureNames = $ScenarioCache | ForEach-Object { $_.Feature.ToString() } | Select-Object -Unique

        # Map elements to their functions
        $ElementFunctionNames = @{ }
        $ScenarioCache `
        | Select-Object -ExpandProperty Elements `
        | ForEach-Object {
            $CurrentElement = $_
            $ElementFunctionName = Get-ElementFunctionName -Element $CurrentElement
            $ElementFunctionNames.Add($CurrentElement, $ElementFunctionName )
        }

        # Find unique function names
        $UniqueFunctionNames =
        $ElementFunctionNames.Values `
        | Select-Object -Unique `
        | Sort-Object { $_ }

        # Build codeunit
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

                    if ($InitializeFunction) { 'Initialize();'; '' }

                    [Given], [When], [Then], [Cleanup] `
                    | ForEach-Object {
                        $CurrentType = $_
                        $CurrentScenario.Elements | Where-Object { $_ -is $CurrentType } | ForEach-Object { "// $_"; "$($ElementFunctionNames[$_])();"; '' }
                    }
                }
            }

            $UniqueFunctionNames | ForEach-Object {
                Procedure $_ -Local {
                    if (-not $DoNotAddErrorToHelperFunctions)
                    {
                        "Error('$_ not implemented.');"
                    }
                }
            }

            if ($InitializeFunction)
            {
                BooleanVariable IsInitialized

                Procedure Initialize -Local {
                    CodeunitVariable LibraryTestInitialize -SubType 132250
                    'LibraryTestInitialize.OnTestInitialize(Codeunit::"{0}");' -f $CodeunitName
                    ''
                    'if IsInitialized then'
                    '  exit;'
                    ''
                    'LibraryTestInitialize.OnBeforeTestSuiteInitialize(Codeunit::"{0}");' -f $CodeunitName
                    ''
                    'IsInitialized := true;'
                    'Commit;'
                    ''
                    'LibraryTestInitialize.OnAfterTestSuiteInitialize(Codeunit::"{0}");' -f $CodeunitName
                }
            }
        }
    }
}
