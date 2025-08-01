<#
    .SYNOPSIS
        Asserts that the specified principal exists as a SQL Server login.

    .DESCRIPTION
        This command asserts that the specified principal exists as a SQL Server login.
        If the principal does not exist as a login, a terminating error is thrown.

    .PARAMETER ServerObject
        Specifies current server connection object.

    .PARAMETER Principal
        Specifies the principal that need to exist as a login.

    .EXAMPLE
        $serverObject = Connect-SqlDscDatabaseEngine -InstanceName 'MyInstance'
        Assert-SqlLogin -ServerObject $serverObject -Principal 'DOMAIN\MyUser'

        Asserts that the principal 'DOMAIN\MyUser' exists as a login on the server.

    .EXAMPLE
        $serverObject = Connect-SqlDscDatabaseEngine -InstanceName 'MyInstance'
        $serverObject | Assert-SqlLogin -Principal 'sa'

        Asserts that the principal 'sa' exists as a login on the server using pipeline input.

    .NOTES
        This command throws a terminating error if the specified principal does not
        exist as a SQL Server login.
#>
function Assert-SqlLogin
{
    [System.Diagnostics.CodeAnalysis.SuppressMessageAttribute('UseSyntacticallyCorrectExamples', '', Justification = 'Because the rule does not yet support parsing the code when a parameter type is not available. The ScriptAnalyzer rule UseSyntacticallyCorrectExamples will always error in the editor due to https://github.com/indented-automation/Indented.ScriptAnalyzerRules/issues/8.')]
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [Microsoft.SqlServer.Management.Smo.Server]
        $ServerObject,

        [Parameter(Mandatory = $true)]
        [System.String]
        $Principal
    )

    process
    {
        $loginExists = $false

        if ($ServerObject.Logins[$Principal])
        {
            $loginExists = $true
        }

        if (-not $loginExists)
        {
            $loginMissingMessage = $script:localizedData.AssertLogin_LoginMissing -f $Principal, $ServerObject.InstanceName

            $PSCmdlet.ThrowTerminatingError(
                [System.Management.Automation.ErrorRecord]::new(
                    $loginMissingMessage,
                    'ASL0001', # cspell: disable-line
                    [System.Management.Automation.ErrorCategory]::InvalidOperation,
                    $Principal
                )
            )
        }

        Write-Verbose -Message ($script:localizedData.AssertLogin_LoginExists -f $Principal)
    }
}