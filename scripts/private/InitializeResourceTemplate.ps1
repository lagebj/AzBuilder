function InitializeResourceTemplate {
    [CmdletBinding()]
    [OutputType([void])]

    Param (
        [Parameter(Position = 0)]
        [System.Collections.Generic.List[AzBuilderScope]] $AzBuilderScope,

        [Parameter(Mandatory, Position = 1)]
        [string] $Path
    )

    try {
        [string[]] $ManagementGroups = $AzBuilderScope | Where-Object -Property 'Scope' -eq 'ManagementGroup' | Select-Object -ExpandProperty 'Name' -Unique
        [string[]] $Subscriptions = $AzBuilderScope | Where-Object -Property 'Scope' -eq 'Subscription' | Select-Object -ExpandProperty 'Name' -Unique
        [string] $TenantTemplateFilePath = '{0}\AzBuilder.Deploy.TenantResources_{1}.json' -f $Path, ((New-Guid).Guid.Substring(0,8))

        [pscustomobject] $TenantTemplateObject = @'
            {
                "$schema": "https://schema.management.azure.com/schemas/2019-08-01/tenantDeploymentTemplate.json#",
                "contentVersion": "1.0.0.0",
                "resources": [],
                "outputs": {
                    "deployments": {
                        "type": "array",
                        "value": []
                    }
                }
            }
'@ | ConvertFrom-Json

        [System.Collections.Generic.List[pscustomobject]] $TenantResourcesToDeploy = @()
        [System.Collections.Generic.List[string]] $Deployments = @()

        foreach ($Item in ($AzBuilderScope | Where-Object -Property 'Scope' -eq 'Tenant')) {
            if ($Item.Templates) {
                [string] $TenantId = $Item.Parent.Split('/')[-1]

                foreach ($TemplateSet in $Item.Templates) {
                    [pscustomobject] $ResourceObject = @'
                        {
                            "type": "Microsoft.Resources/deployments",
                            "apiVersion": "2020-06-01",
                            "name": "",
                            "scope": "",
                            "location": "westeurope",
                            "properties": {
                                "mode": "Incremental",
                                "expressionEvaluationOptions": {
                                    "scope": "Inner"
                                },
                                "parameters": {},
                                "template": {}
                            },
                            "dependsOn": []
                        }
'@ | ConvertFrom-Json

                    $ResourceObject.name = 'AzBuilder.{0}' -f (Split-Path -Path $TemplateSet.TemplateFilePath -LeafBase)
                    $ResourceObject.scope = 'Microsoft.Management/managementGroups/{0}' -f $TenantId
                    $ResourceObject.properties.template = Get-Content -Path $TemplateSet.TemplateFilePath | ConvertFrom-Json
                    $ResourceObject.properties.template.'$schema' = 'https://schema.management.azure.com/schemas/2019-04-01/deploymentTemplate.json#'
                    $Deployments.Add(('[reference(resourceId(''Microsoft.Resources/deployments'', ''{0}'')).outputs.deploymentName.value]' -f $ResourceObject.name))

                    if ($ResourceObject.properties.template.outputs) {
                        $ResourceObject.properties.template = $ResourceObject.properties.template | Select-Object -ExcludeProperty 'outputs'
                    }

                    $ResourceObject.properties.template | Add-Member -MemberType 'NoteProperty' -Name 'outputs' -Value @{
                        deploymentName = @{
                            type = 'string'
                            value = ''
                        }
                    }
                    $ResourceObject.properties.template.outputs.deploymentName.value = $ResourceObject.name

                    if ('{0}' -f $ResourceObject.properties.template.parameters) {
                        $ResourceObject.properties.template.parameters = [pscustomobject] @{
                            input = [pscustomobject] @{
                                type = 'object'
                            }
                        }

                        [pscustomobject] $ParameterObject = Get-Content -Path $TemplateSet.TemplateParametersFilePath | ConvertFrom-Json

                        if (-not $ParameterObject.parameters.input) {
                            $ParameterObject.parameters | Add-Member -MemberType 'NoteProperty' -Name 'input' -Value @{}
                        }

                        [string[]] $ParametersToConvert = ($ParameterObject.parameters | Get-Member -MemberType 'NoteProperty').Name

                        if ($ParametersToConvert -ne 'input') {
                            [pscustomobject] $InputObject = [pscustomobject] @{
                                input = [pscustomobject] @{
                                    value = [pscustomobject] @{}
                                }
                            }

                            foreach ($Parameter in $ParametersToConvert) {
                                if (-not ($Parameter -eq 'input')) {
                                    $InputObject.input.value | Add-Member -MemberType 'NoteProperty' -Name $Parameter -Value $ParameterObject.parameters.$Parameter.value
                                }
                            }

                            $ParameterObject.parameters = $InputObject
                        }

                        $ResourceObject.properties.parameters = $ParameterObject.parameters
                    }

                    if ($ResourceObject.properties.template.resources[0].dependsOn) {
                        [System.Collections.Generic.List[string]] $Dependencies = @()
                        foreach ($Dependency in $ResourceObject.properties.template.resources[0].dependsOn) {
                            $Dependencies.Add(('[resourceId(''Microsoft.Resources/deployments'', ''AzBuilder.{0}'')]' -f $Dependency))
                        }

                        $ResourceObject.dependsOn = [string[]] $Dependencies

                        $ResourceObject.properties.template.resources[0].dependsOn = @()
                    }

                    $TenantResourcesToDeploy.Add($ResourceObject)
                }

                $TenantTemplateObject.resources = [pscustomobject[]] $TenantResourcesToDeploy
                $TenantTemplateObject.outputs.deployments.value = [string[]] $Deployments

                if ($TenantTemplateObject.resources) {
                    $Template = $TenantTemplateObject | ConvertTo-Json -Depth 30

                    FormatTemplate $Template | Out-File $TenantTemplateFilePath
                }
            }
        }

        foreach ($ManagementGroupId in $ManagementGroups) {
            [string] $ManagementGroupPath = '{0}\managementgroups\{1}' -f $Path, $ManagementGroupId
            [string] $ManagementGroupTemplateFilePath = '{0}\AzBuilder.Deploy.ManagementGroupResources_{1}.json' -f $ManagementGroupPath, ((New-Guid).Guid.Substring(0,8))

            if (-not (Test-Path -Path $ManagementGroupPath)) {
                $null = New-Item -Path $ManagementGroupPath -ItemType 'Directory'
            }

            [pscustomobject] $ManagementGroupTemplateObject = @'
                {
                    "$schema": "https://schema.management.azure.com/schemas/2019-08-01/managementGroupDeploymentTemplate.json#",
                    "contentVersion": "1.0.0.0",
                    "resources": [],
                    "outputs": {
                        "deployments": {
                            "type": "array",
                            "value": []
                        }
                    }
                }
'@ | ConvertFrom-Json

            [System.Collections.Generic.List[pscustomobject]] $ManagementGroupResourcesToDeploy = @()
            [System.Collections.Generic.List[string]] $Deployments = @()

            foreach ($Item in ($AzBuilderScope | Where-Object -FilterScript {$_.Scope -eq 'ManagementGroup' -and $_.Name -eq $ManagementGroupId})) {
                if ($Item.Templates) {
                    foreach ($TemplateSet in $Item.Templates) {
                        [pscustomobject] $ResourceObject = @'
                            {
                                "type": "Microsoft.Resources/deployments",
                                "apiVersion": "2020-06-01",
                                "name": "",
                                "scope": "",
                                "location": "westeurope",
                                "properties": {
                                    "mode": "Incremental",
                                    "expressionEvaluationOptions": {
                                        "scope": "Inner"
                                    },
                                    "parameters": {},
                                    "template": {}
                                },
                                "dependsOn": []
                            }
'@ | ConvertFrom-Json

                        $ResourceObject.name = 'AzBuilder.{0}' -f (Split-Path -Path $TemplateSet.TemplateFilePath -LeafBase)
                        $ResourceObject.scope = 'Microsoft.Management/managementGroups/{0}' -f $ManagementGroupId
                        $ResourceObject.properties.template = Get-Content -Path $TemplateSet.TemplateFilePath | ConvertFrom-Json
                        $ResourceObject.properties.template.'$schema' = 'https://schema.management.azure.com/schemas/2019-04-01/deploymentTemplate.json#'
                        $Deployments.Add(('[reference(resourceId(''Microsoft.Resources/deployments'', ''{0}'')).outputs.deploymentName.value]' -f $ResourceObject.name))

                        if ($ResourceObject.properties.template.outputs) {
                            $ResourceObject.properties.template = $ResourceObject.properties.template | Select-Object -ExcludeProperty 'outputs'
                        }

                        $ResourceObject.properties.template | Add-Member -MemberType 'NoteProperty' -Name 'outputs' -Value @{
                            deploymentName = @{
                                type = 'string'
                                value = ''
                            }
                        }
                        $ResourceObject.properties.template.outputs.deploymentName.value = $ResourceObject.name

                        if ('{0}' -f $ResourceObject.properties.template.parameters) {
                            $ResourceObject.properties.template.parameters = [pscustomobject] @{
                                input = [pscustomobject] @{
                                    type = 'object'
                                }
                            }

                            [pscustomobject] $ParameterObject = Get-Content -Path $TemplateSet.TemplateParametersFilePath | ConvertFrom-Json

                            if (-not $ParameterObject.parameters.input) {
                                $ParameterObject.parameters | Add-Member -MemberType 'NoteProperty' -Name 'input' -Value @{}
                            }

                            [string[]] $ParametersToConvert = ($ParameterObject.parameters | Get-Member -MemberType 'NoteProperty').Name

                            if ($ParametersToConvert -ne 'input') {
                                [pscustomobject] $InputObject = [pscustomobject] @{
                                    input = [pscustomobject] @{
                                        value = [pscustomobject] @{}
                                    }
                                }

                                foreach ($Parameter in $ParametersToConvert) {
                                    if (-not ($Parameter -eq 'input')) {
                                        $InputObject.input.value | Add-Member -MemberType 'NoteProperty' -Name $Parameter -Value $ParameterObject.parameters.$Parameter.value
                                    }
                                }

                                $ParameterObject.parameters = $InputObject
                            }

                            $ResourceObject.properties.parameters = $ParameterObject.parameters
                        }

                        if ($ResourceObject.properties.template.resources[0].dependsOn) {
                            [System.Collections.Generic.List[string]] $Dependencies = @()
                            foreach ($Dependency in $ResourceObject.properties.template.resources[0].dependsOn) {
                                $Dependencies.Add(('[resourceId(''Microsoft.Resources/deployments'', ''AzBuilder.{0}'')]' -f $Dependency))
                            }

                            $ResourceObject.dependsOn = [string[]] $Dependencies

                            $ResourceObject.properties.template.resources[0].dependsOn = @()
                        }

                        $ManagementGroupResourcesToDeploy.Add($ResourceObject)
                    }

                    $ManagementGroupTemplateObject.resources = [pscustomobject[]] $ManagementGroupResourcesToDeploy
                    $ManagementGroupTemplateObject.outputs.deployments.value = [string[]] $Deployments

                    if ($ManagementGroupTemplateObject.resources) {
                        $Template = $ManagementGroupTemplateObject | ConvertTo-Json -Depth 30

                        FormatTemplate $Template | Out-File $ManagementGroupTemplateFilePath
                    }
                }
            }
        }

        foreach ($SubscriptionId in $Subscriptions) {
            [string] $SubscriptionPath = '{0}\subscriptions\{1}' -f $Path, $SubscriptionId
            [string] $SubscriptionTemplateFilePath = '{0}\AzBuilder.Deploy.SubscriptionResources_{1}.json' -f $SubscriptionPath, ((New-Guid).Guid.Substring(0,8))

            if (-not (Test-Path -Path $SubscriptionPath)) {
                $null = New-Item -Path $SubscriptionPath -ItemType 'Directory'
            }

            [pscustomobject] $SubscriptionTemplateObject = @'
                {
                    "$schema": "https://schema.management.azure.com/schemas/2018-05-01/subscriptionDeploymentTemplate.json#",
                    "contentVersion": "1.0.0.0",
                    "resources": [],
                    "outputs": {
                        "deployments": {
                            "type": "array",
                            "value": []
                        }
                    }
                }
'@ | ConvertFrom-Json

            [System.Collections.Generic.List[pscustomobject]] $SubscriptionResourcesToDeploy = @()
            [System.Collections.Generic.List[string]] $Deployments = @()

            foreach ($Item in ($AzBuilderScope | Where-Object -FilterScript {$_.Scope -eq 'Subscription' -and $_.Name -eq $SubscriptionId})) {
                if ($Item.Templates) {
                    foreach ($TemplateSet in $Item.Templates) {
                        [pscustomobject] $ResourceObject = @'
                            {
                                "type": "Microsoft.Resources/deployments",
                                "apiVersion": "2020-06-01",
                                "name": "",
                                "subscriptionId": "",
                                "location": "westeurope",
                                "properties": {
                                    "mode": "Incremental",
                                    "expressionEvaluationOptions": {
                                        "scope": "Inner"
                                    },
                                    "parameters": {},
                                    "template": {}
                                },
                                "dependsOn": []
                            }
'@ | ConvertFrom-Json

                        $ResourceObject.name = 'AzBuilder.{0}' -f (Split-Path -Path $TemplateSet.TemplateFilePath -LeafBase)
                        $ResourceObject.subscriptionId = $SubscriptionId
                        $ResourceObject.properties.template = Get-Content -Path $TemplateSet.TemplateFilePath | ConvertFrom-Json
                        $ResourceObject.properties.template.'$schema' = 'https://schema.management.azure.com/schemas/2019-04-01/deploymentTemplate.json#'
                        $Deployments.Add(('[reference(resourceId(''Microsoft.Resources/deployments'', ''{0}'')).outputs.deploymentName.value]' -f $ResourceObject.name))

                        if ($ResourceObject.properties.template.outputs) {
                            $ResourceObject.properties.template = $ResourceObject.properties.template | Select-Object -ExcludeProperty 'outputs'
                        }

                        $ResourceObject.properties.template | Add-Member -MemberType 'NoteProperty' -Name 'outputs' -Value @{
                            deploymentName = @{
                                type = 'string'
                                value = ''
                            }
                        }
                        $ResourceObject.properties.template.outputs.deploymentName.value = $ResourceObject.name

                        if ('{0}' -f $ResourceObject.properties.template.parameters) {
                            $ResourceObject.properties.template.parameters = [pscustomobject] @{
                                input = [pscustomobject] @{
                                    type = 'object'
                                }
                            }

                            [pscustomobject] $ParameterObject = Get-Content -Path $TemplateSet.TemplateParametersFilePath | ConvertFrom-Json

                            if (-not $ParameterObject.parameters.input) {
                                $ParameterObject.parameters | Add-Member -MemberType 'NoteProperty' -Name 'input' -Value @{}
                            }

                            [string[]] $ParametersToConvert = ($ParameterObject.parameters | Get-Member -MemberType 'NoteProperty').Name

                            if ($ParametersToConvert -ne 'input') {
                                [pscustomobject] $InputObject = [pscustomobject] @{
                                    input = [pscustomobject] @{
                                        value = [pscustomobject] @{}
                                    }
                                }

                                foreach ($Parameter in $ParametersToConvert) {
                                    if (-not ($Parameter -eq 'input')) {
                                        $InputObject.input.value | Add-Member -MemberType 'NoteProperty' -Name $Parameter -Value $ParameterObject.parameters.$Parameter.value
                                    }
                                }

                                $ParameterObject.parameters = $InputObject
                            }

                            $ResourceObject.properties.parameters = $ParameterObject.parameters
                        }

                        if ($ResourceObject.properties.template.resources[0].dependsOn) {
                            [System.Generic.Collections.List[string]] $Dependencies = @()
                            foreach ($Dependency in $ResourceObject.properties.template.resources[0].dependsOn) {
                                $Dependencies.Add(('[resourceId(''Microsoft.Resources/deployments'', ''AzBuilder.{0}'')]' -f $Dependency))
                            }

                            $ResourceObject.dependsOn = [string[]] $Dependencies

                            $ResourceObject.properties.template.resources[0].dependsOn = @()
                        }

                        $SubscriptionResourcesToDeploy.Add($ResourceObject)
                    }

                    $SubscriptionTemplateObject.resources = [pscustomobject[]] $SubscriptionResourcesToDeploy
                    $SubscriptionTemplateObject.outputs.deployments.value = [string[]] $Deployments

                    if ($SubscriptionTemplateObject.resources) {
                        $Template = $SubscriptionTemplateObject | ConvertTo-Json -Depth 30

                        FormatTemplate $Template | Out-File $SubscriptionTemplateFilePath
                    }
                }
            }

            foreach ($Item in ($AzBuilderScope | Where-Object -FilterScript {$_.Scope -eq 'ResourceGroup' -and $_.Parent -eq $SubscriptionId})) {
                [string] $ResourceGroupPath = '{0}\subscriptions\{1}\{2}' -f $Path, $SubscriptionId, $Item.Name
                [string] $ResourceGroupTemplateFilePath = '{0}\AzBuilder.Deploy.ResourceGroupResources_{1}.json' -f $ResourceGroupPath, ((New-Guid).Guid.Substring(0,8))

                if (-not (Test-Path -Path $ResourceGroupPath)) {
                    $null = New-Item -Path $ResourceGroupPath -ItemType 'Directory'
                }

                [pscustomobject] $ResourceGroupTemplateObject = @'
                    {
                        "$schema": "https://schema.management.azure.com/schemas/2019-04-01/deploymentTemplate.json#",
                        "contentVersion": "1.0.0.0",
                        "resources": [],
                        "outputs": {
                            "deployments": {
                                "type": "array",
                                "value": []
                            }
                        }
                    }
'@ | ConvertFrom-Json

                [System.Collections.Generic.List[pscustomobject]] $ResourceGroupResourcesToDeploy = @()
                [System.Collections.Generic.List[string]] $Deployments = @()

                if ($Item.Templates) {
                    foreach ($TemplateSet in $Item.Templates) {
                        [pscustomobject] $ResourceObject = @'
                            {
                                "type": "Microsoft.Resources/deployments",
                                "apiVersion": "2020-06-01",
                                "name": "",
                                "resourceGroup": "",
                                "properties": {
                                    "mode": "Incremental",
                                    "expressionEvaluationOptions": {
                                        "scope": "Inner"
                                    },
                                    "parameters": {},
                                    "template": {}
                                }
                            }
'@ | ConvertFrom-Json

                        $ResourceObject.name = 'AzBuilder.{0}' -f (Split-Path -Path $TemplateSet.TemplateFilePath -LeafBase)
                        $ResourceObject.resourceGroup = $Item.Name
                        $ResourceObject.properties.template = Get-Content -Path $TemplateSet.TemplateFilePath | ConvertFrom-Json
                        $ResourceObject.properties.template.'$schema' = 'https://schema.management.azure.com/schemas/2019-04-01/deploymentTemplate.json#'
                        $Deployments.Add(('[reference(resourceId(''Microsoft.Resources/deployments'', ''{0}'')).outputs.deploymentName.value]' -f $ResourceObject.name))

                        if ($ResourceObject.properties.template.outputs) {
                            $ResourceObject.properties.template = $ResourceObject.properties.template | Select-Object -ExcludeProperty 'outputs'
                        }

                        $ResourceObject.properties.template | Add-Member -MemberType 'NoteProperty' -Name 'outputs' -Value @{
                            deploymentName = @{
                                type = 'string'
                                value = ''
                            }
                        }
                        $ResourceObject.properties.template.outputs.deploymentName.value = $ResourceObject.name

                        if ('{0}' -f $ResourceObject.properties.template.parameters) {
                            $ResourceObject.properties.template.parameters = [pscustomobject] @{
                                input = [pscustomobject] @{
                                    type = 'object'
                                }
                            }

                            [pscustomobject] $ParameterObject = Get-Content -Path $TemplateSet.TemplateParametersFilePath | ConvertFrom-Json

                            if (-not $ParameterObject.parameters.input) {
                                $ParameterObject.parameters | Add-Member -MemberType 'NoteProperty' -Name 'input' -Value @{}
                            }

                            [string[]] $ParametersToConvert = ($ParameterObject.parameters | Get-Member -MemberType 'NoteProperty').Name

                            if ($ParametersToConvert -ne 'input') {
                                [pscustomobject] $InputObject = [pscustomobject] @{
                                    input = [pscustomobject] @{
                                        value = [pscustomobject] @{}
                                    }
                                }

                                foreach ($Parameter in $ParametersToConvert) {
                                    if (-not ($Parameter -eq 'input')) {
                                        $InputObject.input.value | Add-Member -MemberType 'NoteProperty' -Name $Parameter -Value $ParameterObject.parameters.$Parameter.value
                                    }
                                }

                                $ParameterObject.parameters = $InputObject
                            }

                            $ResourceObject.properties.parameters = $ParameterObject.parameters
                        }

                        if ($ResourceObject.properties.template.resources[0].dependsOn) {
                            [System.Generic.Collections.List[string]] $Dependencies = @()
                            foreach ($Dependency in $ResourceObject.properties.template.resources[0].dependsOn) {
                                $Dependencies.Add(('[resourceId(''Microsoft.Resources/deployments'', ''AzBuilder.{0}'')]' -f $Dependency))
                            }

                            $ResourceObject.dependsOn = [string[]] $Dependencies

                            $ResourceObject.properties.template.resources[0].dependsOn = @()
                        }

                        $ResourceGroupResourcesToDeploy.Add($ResourceObject)
                    }

                    $ResourceGroupTemplateObject.resources = [pscustomobject[]] $ResourceGroupResourcesToDeploy
                    $ResourceGroupTemplateObject.outputs.deployments.value = [string[]] $Deployments

                    if ($ResourceGroupTemplateObject.resources) {
                        $Template = $ResourceGroupTemplateObject | ConvertTo-Json -Depth 30

                        FormatTemplate $Template | Out-File $ResourceGroupTemplateFilePath
                    }
                }
            }
        }
    } catch {
        $PSCmdlet.ThrowTerminatingError($PSItem)
    }
}
