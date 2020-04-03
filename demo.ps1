Feature 'Foo' {
    Scenario 1 'Baz' {
        Given 'My First Given'
        Given 'My Second Given'
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
} | ConvertTo-CALTestCodeunit 50000 'My Test Codeunit' -InitializeFunction