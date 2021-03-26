function NewDelayResource {
    [CmdletBinding()]
    [OutputType([pscustomobject])]

    Param (
        [Parameter()]
        [int] $Iterations = 20
    )

    try {
        [pscustomobject] $DeploymentDelayResourceObject = @'
            {
                "type": "Microsoft.Resources/deployments",
                "apiVersion": "2020-06-01",
                "name": "[concat('DeploymentDelay', copyIndex())]",
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
                        "$schema": "https://schema.management.azure.com/schemas/2019-04-01/deploymentTemplate.json#",
                        "contentVersion": "1.0.0.0",
                        "parameters": {},
                        "resources": [],
                        "outputs": {}
                    }
                }
            }
'@ | ConvertFrom-Json

        $DeploymentDelayResourceObject.scope = $Scope
        $DeploymentDelayResourceObject.dependsOn = $DependsOn
        $DeploymentDelayResourceObject.copy.count = $Iterations

        return $DeploymentDelayResourceObject
    } catch {
        $PSCmdlet.ThrowTerminatingError($PSItem)
    }
}
