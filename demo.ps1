. ./ConvertTo-CALTestCodeunit.ps1

$MyFeature = Feature 'Foo' {
    Scenario 1 'Baz' {
        Given 'My first given'
        Given 'My second given'
        When 'My When'
        Then 'My First Then'
        Then 'My Second Then'
    }

    Scenario 2 'Bar' {
        Given 'My First Given'
        Given 'My Other Given'
        When 'My Other When'
        Then 'My First Other Then'
    }
}

$MyFeature `
| ConvertTo-CALTestCodeunit 50000 'My Test Codeunit' -InitializeFunction `
| Export-CBreezeApplication -Path ~\Desktop\MyTestCodeunit.txt