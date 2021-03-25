function InitializeResourceGroupTemplate {
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
        [string[]] $Subscriptions = $AzBuilderScope | Where-Object -Property 'Scope' -eq 'ResourceGroup' | Select-Object -ExpandProperty 'Parent' -Unique

        foreach ($SubscriptionId in $Subscriptions) {
            [string] $SubscriptionPath = '{0}\subscriptions\{1}' -f $Path, $SubscriptionId
            [string] $DeploymentName = 'AzBuilder.Deploy.ResourceGroups_{0}' -f ((New-Guid).Guid.Substring(0,8))
            [string] $TemplateFilePath = '{0}\{1}.json' -f $SubscriptionPath, $DeploymentName

            if (-not (Test-Path -Path $SubscriptionPath)) {
                $null = New-Item -Path $SubscriptionPath -ItemType 'Directory'
            }

            [pscustomobject] $TemplateObject = @'
                {
                    "$schema": "https://schema.management.azure.com/schemas/2018-05-01/subscriptionDeploymentTemplate.json#",
                    "contentVersion": "1.0.0.0",
                    "resources": []
                }
'@ | ConvertFrom-Json

            [System.Collections.Generic.List[pscustomobject]] $ResourceGroupsToDeploy = @()

            foreach ($Item in ($AzBuilderScope | Where-Object -FilterScript {$_.Scope -eq 'ResourceGroup' -and $_.Parent -eq $SubscriptionId})) {
                if ($Item.Deploy) {
                    [pscustomobject] $ResourceGroupObject = @'
                        {
                            "type": "Microsoft.Resources/resourceGroups",
                            "apiVersion": "2020-06-01",
                            "name": "",
                            "location": "",
                            "tags": {},
                            "properties": {}
                        }
'@  | ConvertFrom-Json

                    $ResourceGroupObject.name = $Item.Name
                    $ResourceGroupObject.location = $Item.Location

                    $ResourceGroupsToDeploy.Add($ResourceGroupObject)
                }
            }

            $TemplateObject.resources = [pscustomobject[]] $ResourceGroupsToDeploy

            if ($TemplateObject.resources) {
                $Template = $TemplateObject | ConvertTo-Json -Depth 30

                FormatTemplate $Template | Out-File $TemplateFilePath

                [pscustomobject] $DeploymentDetails = [pscustomobject] @{
                    DeploymentName = $DeploymentName
                    Resources = $TemplateObject.resources.name
                }

                $DeploymentsList.Add($DeploymentDetails)
            }
        }

        if ($DeploymentsList) {
            [pscustomobject[]] $DeploymentsList = $DeploymentsList

            return $DeploymentsList
        }
    } catch {
        $PSCmdlet.ThrowTerminatingError($PSItem)
    }
}
