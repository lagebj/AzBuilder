function InitializeManagementGroupTemplate {
    [CmdletBinding()]
    [OutputType([pscustomobject[]])]

    Param (
        [Parameter(Position = 0)]
        [System.Collections.Generic.List[AzBuilderScope]] $AzBuilderScope,

        [Parameter(Mandatory, Position = 1)]
        [string] $Path
    )

    try {
        [System.Collections.Generic.List[pscustomobject]] $DeploymentsList = @()
        [string] $DeploymentName = 'AzBuilder.Deploy.ManagementGroups_{0}' -f ((New-Guid).Guid.Substring(0,8))
        [string] $TemplateFilePath = '{0}\{1}.json' -f $Path, $DeploymentName

        [pscustomobject] $TemplateObject = @'
            {
                "$schema": "https://schema.management.azure.com/schemas/2019-08-01/tenantDeploymentTemplate.json#",
                "contentVersion": "1.0.0.0",
                "resources": []
            }
'@ | ConvertFrom-Json

        [System.Collections.Generic.List[pscustomobject]] $ManagementGroupsToDeploy = @()

        foreach ($Item in ($AzBuilderScope | Where-Object -Property 'Scope' -eq 'ManagementGroup')) {
            if ($Item.Deploy) {
                [pscustomobject] $ManagementGroupObject = @'
                    {
                        "type": "Microsoft.Management/managementGroups",
                        "apiVersion": "2020-05-01",
                        "name": "",
                        "properties": {
                            "displayName": "",
                            "details": {
                                "parent": {
                                    "id": ""
                                }
                            }
                        }
                    }
'@  | ConvertFrom-Json

                $ManagementGroupObject.name = $Item.Name
                $ManagementGroupObject.properties.displayName = $Item.Name

                if (-not ($Item.ParentId)) {
                    $ManagementGroupObject.properties.details.parent.id = '[tenantResourceId(''Microsoft.Management/managementGroups'', ''{0}'')]' -f $Item.Parent
                    $ManagementGroupObject | Add-Member -MemberType 'NoteProperty' -Name 'dependsOn' -Value @(('[tenantResourceId(''Microsoft.Management/managementGroups/'', ''{0}'')]' -f $Item.Parent))
                } else {
                    $ManagementGroupObject.properties.details.parent.id = $Item.ParentId
                }

                $ManagementGroupsToDeploy.Add($ManagementGroupObject)
            }
        }

        $TemplateObject.resources = [pscustomobject[]] $ManagementGroupsToDeploy

        if ($TemplateObject.resources) {
            $Template = $TemplateObject | ConvertTo-Json -Depth 30

            FormatTemplate $Template | Out-File $TemplateFilePath

            [pscustomobject] $DeploymentDetails = [pscustomobject] @{
                DeploymentName = $DeploymentName
                Resources = $TemplateObject.resources.name
            }

            $DeploymentsList.Add($DeploymentDetails)
        }

        if ($DeploymentsList) {
            [pscustomobject[]] $DeploymentsList = $DeploymentsList

            return $DeploymentsList
        }
    } catch {
        $PSCmdlet.ThrowTerminatingError($PSItem)
    }
}
