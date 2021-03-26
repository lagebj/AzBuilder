function NewDelayResource {
    [CmdletBinding()]
    [OutputType([pscustomobject])]

    Param (
        [Parameter(Mandatory)]
        [string] $ResourceName,

        [Parameter(Mandatory)]
        [string] $Scope,

        [Parameter()]
        [int] $Iterations = 20,

        [Parameter()]
        [string[]] $DependsOn = @()
    )

    try {
        [string] $DeploymentName = 'DelayFor{0}_{1}' -f $Iterations, $ResourceName

        [pscustomobject] $DeploymentDelayResourceObject = @'
            {
                "type": "Microsoft.Resources/deployments",
                "apiVersion": "2019-10-01",
                "name": "",
                "location": "[deployment().location]",
                "scope": "",
                "dependsOn": [],
                "copy": {
                    "batchSize": 1,
                    "count": 0,
                    "mode": "Serial",
                    "name": "DeploymentDelay"
                },
                "properties": {
                    "mode": "Incremental",
                    "template": {
                        "$schema": "https://schema.management.azure.com/schemas/2019-08-01/managementGroupDeploymentTemplate.json#",
                        "contentVersion": "1.0.0.0",
                        "parameters": {},
                        "resources": [],
                        "outputs": {}
                    }
                }
            }
'@ | ConvertFrom-Json

        $DeploymentDelayResourceObject.name = $DeploymentName
        $DeploymentDelayResourceObject.scope = $Scope
        $DeploymentDelayResourceObject.dependsOn = $DependsOn
        $DeploymentDelayResourceObject.copy.count = $Iterations

        return $DeploymentDelayResourceObject
    } catch {
        $PSCmdlet.ThrowTerminatingError($PSItem)
    }
}
