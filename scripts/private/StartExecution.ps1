function StartExecution {
    [CmdletBinding()]
    [OutputType([void])]

    Param (
        [Parameter(Mandatory, Position = 0)]
        [scriptblock] $ScriptBlock,

        [Parameter()]
        [switch] $IgnoreExitcode,

        [Parameter()]
        [switch] $VerboseOutputOnError
    )

    [System.Management.Automation.ActionPreference] $script:ErrorActionPreference = [System.Management.Automation.ActionPreference]::Continue

    try {
        if ($PSBoundParameters.ContainsKey('VerboseOutputOnError')) {
            [string[]] $Output = & $ScriptBlock 2>&1
        } else {
            & $ScriptBlock
        }

        if ($LASTEXITCODE -ne 0 -and -not $PSBoundParameters.ContainsKey('IgnoreExitcode')) {
            if ($PSBoundParameters.ContainsKey('VerboseOutputOnError') -and $Output) {
                $Output | Out-String | Write-Verbose -Verbose
            }

            [System.Management.Automation.CallStackFrame[]] $Caller = Get-PSCallStack -ErrorAction 'SilentlyContinue'
            if ($Caller) {
                [string[]] $CallerLocationParts = $Caller[1].Location -split ":\s*line\s*"
                [string] $CallerFile = $CallerLocationParts[0]
                [string] $CallerLine = $CallerLocationParts[1]

                throw ('Execution of {{{0}}} by {1}: line {2} failed with exit code {3}' -f $ScriptBlock, $CallerFile, $CallerLine, $LASTEXITCODE)
            }
            throw ('Execution of {{{0}}} failed with exit code {1}' -f $ScriptBlock, $LASTEXITCODE)
        }
    } catch {
        $PSCmdlet.ThrowTerminatingError($PSItem)
    }
}
