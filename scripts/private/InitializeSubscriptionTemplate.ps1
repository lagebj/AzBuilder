function InitializeSubscriptionTemplate {
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
        [string] $DeploymentName = 'AzBuilder.Move.Subscriptions_{0}' -f ((New-Guid).Guid.Substring(0,8))
        [string] $TemplateFilePath = '{0}\{1}.json' -f $Path, $DeploymentName

        [pscustomobject] $TemplateObject = @'
            {
                "$schema": "https://schema.management.azure.com/schemas/2019-08-01/tenantDeploymentTemplate.json#",
                "contentVersion": "1.0.0.0",
                "resources": []
            }
'@ | ConvertFrom-Json

        [System.Collections.Generic.List[pscustomobject]] $SubscriptionsToMove = @()

        foreach ($Item in ($AzBuilderScope | Where-Object -Property 'Scope' -eq 'Subscription')) {
            if (-not ($Item.Parent -eq 'Tenant Root Group')) {
                [pscustomobject] $SubscriptionObject = @'
                    {
                        "type": "Microsoft.Management/managementGroups/subscriptions",
                        "apiVersion": "2020-05-01",
                        "name": "",
                        "properties": {}
                    }
'@  | ConvertFrom-Json

                $SubscriptionObject.name = '{0}/{1}' -f $Item.Parent, $Item.Name

                $SubscriptionsToMove.Add($SubscriptionObject)
            }
        }

        $TemplateObject.resources = [pscustomobject[]] $SubscriptionsToMove

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
