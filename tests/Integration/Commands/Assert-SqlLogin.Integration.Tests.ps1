[System.Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseDeclaredVarsMoreThanAssignments', '', Justification = 'Suppressing this rule because Script Analyzer does not understand Pester syntax.')]
param ()

BeforeDiscovery {
    try
    {
        if (-not (Get-Module -Name 'DscResource.Test'))
        {
            # Assumes dependencies has been resolved, so if this module is not available, run 'noop' task.
            if (-not (Get-Module -Name 'DscResource.Test' -ListAvailable))
            {
                # Redirect all streams to $null, except the error stream (stream 2)
                & "$PSScriptRoot/../../../build.ps1" -Tasks 'noop' 3>&1 4>&1 5>&1 6>&1 > $null
            }

            # If the dependencies has not been resolved, this will throw an error.
            Import-Module -Name 'DscResource.Test' -Force -ErrorAction 'Stop'
        }
    }
    catch [System.IO.FileNotFoundException]
    {
        throw 'DscResource.Test module dependency not found. Please run ".\build.ps1 -ResolveDependency -Tasks build" first.'
    }
}

BeforeAll {
    $script:dscModuleName = 'SqlServerDsc'

    Import-Module -Name $script:dscModuleName
}

# cSpell: ignore DSCSQLTEST
Describe 'Assert-SqlLogin' -Tag @('Integration_SQL2016', 'Integration_SQL2017', 'Integration_SQL2019', 'Integration_SQL2022') {
    BeforeAll {
        $script:instanceName = 'DSCSQLTEST'
        
        # Connect to the test instance
        $script:serverObject = Connect-SqlDscDatabaseEngine -InstanceName $script:instanceName
    }

    Context 'When asserting a login that exists' {
        BeforeAll {
            # Create a test login for the integration test
            $script:testLoginName = 'IntegrationTestLogin'
            $script:testLoginPassword = 'P@ssw0rd123!'
            
            # Create the test login using T-SQL as setup (not part of the function being tested)
            $createLoginQuery = "IF NOT EXISTS (SELECT * FROM sys.sql_logins WHERE name = '$script:testLoginName')
                                 CREATE LOGIN [$script:testLoginName] WITH PASSWORD = '$script:testLoginPassword'"
            Invoke-SqlDscQuery -ServerObject $script:serverObject -Query $createLoginQuery
        }

        AfterAll {
            # Clean up the test login
            $dropLoginQuery = "IF EXISTS (SELECT * FROM sys.sql_logins WHERE name = '$script:testLoginName')
                               DROP LOGIN [$script:testLoginName]"
            try {
                Invoke-SqlDscQuery -ServerObject $script:serverObject -Query $dropLoginQuery
            }
            catch {
                Write-Warning "Failed to clean up test login '$script:testLoginName': $_"
            }
        }

        It 'Should not throw an error when asserting an existing login' {
            { Assert-SqlLogin -ServerObject $script:serverObject -Principal $script:testLoginName } |
                Should -Not -Throw
        }

        It 'Should not throw an error when using pipeline input' {
            { $script:serverObject | Assert-SqlLogin -Principal $script:testLoginName } |
                Should -Not -Throw
        }
    }

    Context 'When asserting a login that does not exist' {
        BeforeAll {
            $script:nonExistentLoginName = 'NonExistentLogin_Integration_Test'
        }

        It 'Should throw a terminating error when asserting a non-existent login' {
            { Assert-SqlLogin -ServerObject $script:serverObject -Principal $script:nonExistentLoginName } |
                Should -Throw -ErrorId 'ASL0001'
        }

        It 'Should throw a terminating error when using pipeline input' {
            { $script:serverObject | Assert-SqlLogin -Principal $script:nonExistentLoginName } |
                Should -Throw -ErrorId 'ASL0001'
        }
    }

    Context 'When asserting system logins' {
        It 'Should not throw an error when asserting the sa login' {
            { Assert-SqlLogin -ServerObject $script:serverObject -Principal 'sa' } |
                Should -Not -Throw
        }

        It 'Should not throw an error when asserting NT AUTHORITY\SYSTEM login' {
            { Assert-SqlLogin -ServerObject $script:serverObject -Principal 'NT AUTHORITY\SYSTEM' } |
                Should -Not -Throw
        }
    }
}