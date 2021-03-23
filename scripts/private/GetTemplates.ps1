function GetTemplates {
    [CmdletBinding()]
    [OutputType([System.Collections.Generic.List[pscustomobject]])]

    Param (
        [Parameter(Mandatory, Position = 0)]
        [System.IO.FileInfo[]] $Templates
    )

    try {
        [System.Collections.Generic.List[pscustomobject]] $TemplateFiles = @()

        foreach ($File in $Templates) {
            if (-not ($File.BaseName -like '*.parameters')) {
                [string] $TemplateParametersFilePath = '{0}\{1}.parameters.json' -f (Split-Path -Path $File.FullName), $File.BaseName

                if (Test-Path -Path $TemplateParametersFilePath) {
                    $TemplateFiles.Add([pscustomobject] @{
                        TemplateFilePath = $File.FullName
                        TemplateParametersFilePath = $TemplateParametersFilePath
                    })
                }
            }
        }

        return $TemplateFiles
    } catch {
        $PSCmdlet.ThrowTerminatingError($PSItem)
    }
}

