function FormatTemplate {
    [CmdletBinding()]
    [OutputType([string])]

    Param (
        [Parameter(Mandatory, Position = 0)]
        [string] $Template
    )

    try {
        [System.Collections.Generic.List[pscustomobject]] $TemporaryParameterList = @()
        [System.Collections.Generic.List[pscustomobject]] $TemporaryDefinitionList = @()
        [pscustomobject] $TemplateObject = $Template | ConvertFrom-Json

        for ($i = 0; $i -lt $TemplateObject.resources.Count; $i++) {
            [pscustomobject] $ParameterObject = $TemplateObject.resources[$i].properties.parameters

            if ($ParameterObject) {
                $ParameterObject | Add-Member -MemberType 'NoteProperty' -Name 'parent' -Value $TemplateObject.resources[$i].name

                $TemporaryParameterList.Add($ParameterObject)

                $TemplateObject.resources[$i].properties.parameters = [pscustomobject] @{}
            }

            if ($TemplateObject.resources[$i].properties.template) {
                if (($TemplateObject.resources[$i].properties.template.resources[0].type -eq 'Microsoft.Authorization/policyDefinitions') -or ($TemplateObject.resources[$i].properties.template.resources[0].type -eq 'Microsoft.Authorization/policySetDefinitions')) {
                    [pscustomobject] $PropertiesObject = $TemplateObject.resources[$i].properties.template.resources[0].properties

                    if ($PropertiesObject) {
                        $PropertiesObject | Add-Member -MemberType 'NoteProperty' -Name 'parent' -Value $TemplateObject.resources[$i].name

                        $TemporaryDefinitionList.Add($PropertiesObject)

                        $TemplateObject.resources[$i].properties.template.resources[0].properties = [pscustomobject] @{}
                    }
                }
            }
        }

        [string] $Template = $TemplateObject | ConvertTo-Json -Depth 30
        [regex] $Pattern = [regex]::new('(?i)((?:parameters\([''"])(\w+)(?:[''"]\)))')

        [Microsoft.PowerShell.Commands.MatchInfo] $TemplatePatternMatches = $Template | Select-String -Pattern $Pattern -AllMatches

        if ($TemplatePatternMatches) {
            foreach ($MatchItem in $TemplatePatternMatches.Matches) {
                if (-not ($MatchItem.Groups[2].Value -eq 'input')) {
                    [string] $Template = $Template.Replace($MatchItem.Value, ('parameters(''input'').{0}' -f $MatchItem.Groups[2].Value))
                }
            }
        }

        [pscustomobject] $TemplateObject = $Template | ConvertFrom-Json

        foreach ($Parameter in $TemporaryParameterList) {
            for ($i = 0; $i -lt $TemplateObject.resources.Count; $i++) {
                if ($TemplateObject.resources[$i].name -eq $Parameter.parent) {
                    $TemplateObject.resources[$i].properties.parameters = $Parameter | Select-Object -ExcludeProperty 'parent'
                }
            }
        }

        foreach ($PropertyDefinition in $TemporaryDefinitionList) {
            for ($i = 0; $i -lt $TemplateObject.resources.Count; $i++) {
                if ($TemplateObject.resources[$i].name -eq $PropertyDefinition.parent) {
                    $TemplateObject.resources[$i].properties.template.resources[0].properties = $PropertyDefinition | Select-Object -ExcludeProperty 'parent'
                }
            }
        }

        [string] $Template = $TemplateObject | ConvertTo-Json -Depth 30

        return $Template
    } catch {
        $PSCmdlet.ThrowTerminatingError($PSItem)
    }
}
