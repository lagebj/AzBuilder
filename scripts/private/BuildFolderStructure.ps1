function BuildFolderStructure {
    [CmdletBinding()]
    [OutputType([void])]

    Param (
        [Parameter(Position = 0)]
        [System.Collections.Generic.List[AzBuilderScope]] $AzBuilderScope,

        [Parameter(Mandatory, Position = 1)]
        [string] $Path
    )

    try {
        foreach ($Object in $AzBuilderScope) {
            if (-not ($Object.Scope -eq 'ResourceGroup')) {
                [string] $ObjectPath = '{0}\{1}' -f $Path, $Object.Path
            } else {
                [string] $ObjectPath = '{0}\{1} ({2})' -f $Path, $Object.Path, $Object.Location
            }

            if (-not (Test-Path -Path $ObjectPath)) {
                $null = New-Item -Path $ObjectPath -ItemType 'Directory' -Force
            }
        }
    } catch {
        $PSCmdlet.ThrowTerminatingError($PSItem)
    }
}
