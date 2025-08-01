[System.Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseDeclaredVarsMoreThanAssignments', '')]
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

    $env:SqlServerDscCI = $true

    Import-Module -Name $script:dscModuleName

    # Loading mocked classes
    Add-Type -Path (Join-Path -Path (Join-Path -Path $PSScriptRoot -ChildPath '../Stubs') -ChildPath 'SMO.cs')

    $PSDefaultParameterValues['InModuleScope:ModuleName'] = $script:dscModuleName
    $PSDefaultParameterValues['Mock:ModuleName'] = $script:dscModuleName
    $PSDefaultParameterValues['Should:ModuleName'] = $script:dscModuleName
}

AfterAll {
    $PSDefaultParameterValues.Remove('InModuleScope:ModuleName')
    $PSDefaultParameterValues.Remove('Mock:ModuleName')
    $PSDefaultParameterValues.Remove('Should:ModuleName')

    # Unload the module being tested so that it doesn't impact any other tests.
    Get-Module -Name $script:dscModuleName -All | Remove-Module -Force

    Remove-Item -Path 'env:SqlServerDscCI'
}

Describe 'Assert-SqlLogin' -Tag 'Public' {
    Context 'When the instance does not have the specified principal' {
        BeforeAll {
            $mockServerObject = New-Object -TypeName 'Microsoft.SqlServer.Management.Smo.Server' |
                Add-Member -MemberType 'ScriptProperty' -Name 'Logins' -Value {
                    return @{
                        'DOMAIN\MyLogin' = New-Object -TypeName Object |
                            Add-Member -MemberType 'NoteProperty' -Name 'Name' -Value 'DOMAIN\MyLogin' -PassThru -Force
                    }
                } -PassThru -Force |
                Add-Member -MemberType 'NoteProperty' -Name 'InstanceName' -Value 'TestInstance' -PassThru -Force

            $mockLocalizedStringLoginMissing = InModuleScope -ScriptBlock { $script:localizedData.AssertLogin_LoginMissing }
        }

        It 'Should throw a terminating error with the correct error ID' {
            $errorId = 'ASL0001'
            $expectedErrorMessage = $mockLocalizedStringLoginMissing -f 'UnknownUser', 'TestInstance'

            { Assert-SqlLogin -ServerObject $mockServerObject -Principal 'UnknownUser' } |
                Should -Throw -ExpectedMessage $expectedErrorMessage -ErrorId $errorId
        }

        It 'Should throw a terminating error with InvalidOperation category' {
            { Assert-SqlLogin -ServerObject $mockServerObject -Principal 'UnknownUser' } |
                Should -Throw -ErrorId 'ASL0001'
        }

        Context 'When passing ServerObject over the pipeline' {
            It 'Should throw a terminating error' {
                $errorId = 'ASL0001'

                { $mockServerObject | Assert-SqlLogin -Principal 'UnknownUser' } |
                    Should -Throw -ErrorId $errorId
            }
        }
    }

    Context 'When the instance has the specified principal' {
        BeforeAll {
            $mockServerObject = New-Object -TypeName 'Microsoft.SqlServer.Management.Smo.Server' |
                Add-Member -MemberType 'ScriptProperty' -Name 'Logins' -Value {
                    return @{
                        'DOMAIN\MyLogin' = New-Object -TypeName Object |
                            Add-Member -MemberType 'NoteProperty' -Name 'Name' -Value 'DOMAIN\MyLogin' -PassThru -Force
                    }
                } -PassThru -Force |
                Add-Member -MemberType 'NoteProperty' -Name 'InstanceName' -Value 'TestInstance' -PassThru -Force

            $mockLocalizedStringLoginExists = InModuleScope -ScriptBlock { $script:localizedData.AssertLogin_LoginExists }
        }

        It 'Should not throw an error and complete successfully' {
            { Assert-SqlLogin -ServerObject $mockServerObject -Principal 'DOMAIN\MyLogin' } |
                Should -Not -Throw
        }

        It 'Should output verbose message when login exists' {
            $expectedVerboseMessage = $mockLocalizedStringLoginExists -f 'DOMAIN\MyLogin'

            Assert-SqlLogin -ServerObject $mockServerObject -Principal 'DOMAIN\MyLogin' -Verbose 4>&1 |
                Should -Match ([regex]::Escape($expectedVerboseMessage))
        }

        Context 'When passing ServerObject over the pipeline' {
            It 'Should not throw an error and complete successfully' {
                { $mockServerObject | Assert-SqlLogin -Principal 'DOMAIN\MyLogin' } |
                    Should -Not -Throw
            }
        }
    }

    Context 'When testing multiple login scenarios' {
        BeforeAll {
            $mockServerObject = New-Object -TypeName 'Microsoft.SqlServer.Management.Smo.Server' |
                Add-Member -MemberType 'ScriptProperty' -Name 'Logins' -Value {
                    return @{
                        'sa' = New-Object -TypeName Object |
                            Add-Member -MemberType 'NoteProperty' -Name 'Name' -Value 'sa' -PassThru -Force
                        'DOMAIN\ServiceAccount' = New-Object -TypeName Object |
                            Add-Member -MemberType 'NoteProperty' -Name 'Name' -Value 'DOMAIN\ServiceAccount' -PassThru -Force
                        'LocalUser' = New-Object -TypeName Object |
                            Add-Member -MemberType 'NoteProperty' -Name 'Name' -Value 'LocalUser' -PassThru -Force
                    }
                } -PassThru -Force |
                Add-Member -MemberType 'NoteProperty' -Name 'InstanceName' -Value 'TestInstance' -PassThru -Force
        }

        It 'Should not throw an error for existing login: sa' {
            { Assert-SqlLogin -ServerObject $mockServerObject -Principal 'sa' } |
                Should -Not -Throw
        }

        It 'Should not throw an error for existing login: DOMAIN\ServiceAccount' {
            { Assert-SqlLogin -ServerObject $mockServerObject -Principal 'DOMAIN\ServiceAccount' } |
                Should -Not -Throw
        }

        It 'Should not throw an error for existing login: LocalUser' {
            { Assert-SqlLogin -ServerObject $mockServerObject -Principal 'LocalUser' } |
                Should -Not -Throw
        }

        It 'Should throw an error for non-existing login: NonExistentUser' {
            { Assert-SqlLogin -ServerObject $mockServerObject -Principal 'NonExistentUser' } |
                Should -Throw -ErrorId 'ASL0001'
        }

        It 'Should throw an error for non-existing login: DOMAIN\NonExistentUser' {
            { Assert-SqlLogin -ServerObject $mockServerObject -Principal 'DOMAIN\NonExistentUser' } |
                Should -Throw -ErrorId 'ASL0001'
        }
    }
}