function GetResources {
    [CmdletBinding()]
    [OutputType([void])]

    Param (
        [Parameter(Position = 0)]
        [System.Collections.Generic.List[AzBuilderScope]] $AzBuilderScope,

        [Parameter(Mandatory, Position = 1)]
        [string] $Path,

        [Parameter(Position = 2)]
        [string] $TemporaryPath = '{0}\azbuilder-blueprints' -f $env:TEMP
    )

    try {
        [regex] $GuidRegex = [regex]::new('(?i)[a-z0-9]{8}-([a-z0-9]{4}-){3}[a-z0-9]{12}')
        [Microsoft.Azure.Commands.Profile.Models.PSAzureSubscription[]] $Subscriptions = Get-AzSubscription | Where-Object -Property 'State' -eq 'Enabled'

        foreach ($Subscription in $Subscriptions) {
            $null = Set-AzContext -SubscriptionObject $Subscription

            [Microsoft.Azure.Commands.ResourceManager.Cmdlets.Implementation.Policy.PsPolicyDefinition[]] $PolicyDefinitions = Get-AzPolicyDefinition -Custom

            foreach ($PolicyDefinition in $PolicyDefinitions) {
                if (-not ($PolicyDefinition.ResourceId.Split('/')[1] -eq 'subscriptions')) {
                    [string] $PolicyDefinitionScope = $PolicyDefinition.ResourceId.Split('/')[4]

                    if ($PolicyDefinitionScope -match $GuidRegex) {
                        [string] $PolicyDefinitionScope = 'Tenant'
                    }
                } else {
                    [string] $PolicyDefinitionScope = $PolicyDefinition.ResourceId.Split('/')[2]
                }

                [string[]] $ResourceType = $PolicyDefinition.ResourceType.Split('/')
                [string] $ResourceFileName = '{0}_{1}-{2}.json' -f $ResourceType[0], $ResourceType[1], $PolicyDefinition.Name

                [pscustomobject] $TemplateObject = @'
                    {
                        "$schema": "",
                        "contentVersion": "1.0.0.0",
                        "parameters": {},
                        "variables": {},
                        "resources": []
                    }
'@ | ConvertFrom-Json

                if ($PolicyDefinitionScope -eq 'Tenant') {
                    [string] $ResourceFilePath = '{0}\.state\{1}' -f $Path, $ResourceFileName
                    [string] $Schema = 'https://schema.management.azure.com/schemas/2019-08-01/managementGroupDeploymentTemplate.json#'
                } else {
                    [AzBuilderScope] $Item = $AzBuilderScope | Where-Object -Property 'Name' -eq $PolicyDefinitionScope
                    [string] $ResourceFilePath = '{0}\{1}\.state\{2}' -f $Path, $Item.Path, $ResourceFileName

                    if ($Item.Scope -eq 'ManagementGroup') {
                        [string] $Schema = 'https://schema.management.azure.com/schemas/2019-08-01/managementGroupDeploymentTemplate.json#'
                    } else {
                        [string] $Schema = 'https://schema.management.azure.com/schemas/2018-05-01/subscriptionDeploymentTemplate.json#'
                    }
                }

                [pscustomobject] $ResourceObject = @'
                    {
                        "type": "Microsoft.Authorization/policyDefinitions",
                        "apiVersion": "2020-03-01",
                        "name": "",
                        "properties": {}
                    }
'@ | ConvertFrom-Json

                $ResourceObject.name = $PolicyDefinition.Name
                $ResourceObject.properties = $PolicyDefinition.Properties

                $TemplateObject.'$schema' = $Schema
                $TemplateObject.resources = @($ResourceObject)

                if (-not (Test-Path -Path ($StateFolderPath = Split-Path -Path $ResourceFilePath))) {
                    $null = New-Item -Path $StateFolderPath -ItemType 'Directory'
                }

                $TemplateObject | ConvertTo-Json -Depth 30 | Out-File -FilePath $ResourceFilePath
            }

            [Microsoft.Azure.Commands.ResourceManager.Cmdlets.Implementation.Policy.PsPolicySetDefinition[]] $PolicySetDefinitions = Get-AzPolicySetDefinition -Custom

            foreach ($PolicySetDefinition in $PolicySetDefinitions) {
                if (-not ($PolicySetDefinition.ResourceId.Split('/')[1] -eq 'subscriptions')) {
                    [string] $PolicySetDefinitionScope = $PolicySetDefinition.ResourceId.Split('/')[4]

                    if ($PolicySetDefinitionScope -match $GuidRegex) {
                        [string] $PolicySetDefinitionScope = 'Tenant'
                    }
                } else {
                    [string] $PolicySetDefinitionScope = $PolicySetDefinition.ResourceId.Split('/')[2]
                }

                [string[]] $ResourceType = $PolicySetDefinition.ResourceType.Split('/')
                [string] $ResourceFileName = '{0}_{1}-{2}.json' -f $ResourceType[0], $ResourceType[1], $PolicySetDefinition.Name

                [pscustomobject] $TemplateObject = @'
                    {
                        "$schema": "",
                        "contentVersion": "1.0.0.0",
                        "parameters": {},
                        "variables": {},
                        "resources": []
                    }
'@ | ConvertFrom-Json

                if ($PolicySetDefinitionScope -eq 'Tenant') {
                    [string] $ResourceFilePath = '{0}\.state\{1}' -f $Path, $ResourceFileName
                    [string] $Schema = 'https://schema.management.azure.com/schemas/2019-08-01/managementGroupDeploymentTemplate.json#'
                } else {
                    [AzBuilderScope] $Item = $AzBuilderScope | Where-Object -Property 'Name' -eq $PolicySetDefinitionScope
                    [string] $ResourceFilePath = '{0}\{1}\.state\{2}' -f $Path, $Item.Path, $ResourceFileName

                    if ($Item.Scope -eq 'ManagementGroup') {
                        [string] $Schema = 'https://schema.management.azure.com/schemas/2019-08-01/managementGroupDeploymentTemplate.json#'
                    } else {
                        [string] $Schema = 'https://schema.management.azure.com/schemas/2018-05-01/subscriptionDeploymentTemplate.json#'
                    }
                }

                [pscustomobject] $ResourceObject = @'
                    {
                        "type": "Microsoft.Authorization/policySetDefinitions",
                        "apiVersion": "2020-03-01",
                        "name": "",
                        "properties": {}
                    }
'@ | ConvertFrom-Json

                $ResourceObject.name = $PolicySetDefinition.Name
                $ResourceObject.properties = $PolicySetDefinition.Properties

                $TemplateObject.'$schema' = $Schema
                $TemplateObject.resources = @($ResourceObject)

                if (-not (Test-Path -Path ($StateFolderPath = Split-Path -Path $ResourceFilePath))) {
                    $null = New-Item -Path $StateFolderPath -ItemType 'Directory'
                }

                $TemplateObject | ConvertTo-Json -Depth 30 | Out-File -FilePath $ResourceFilePath -Force
            }

            [Microsoft.Azure.Commands.ResourceManager.Cmdlets.Implementation.Policy.PsPolicyAssignment[]] $PolicyAssignments = Get-AzPolicyAssignment

            foreach ($PolicyAssignment in $PolicyAssignments) {
                if (-not ($PolicyAssignment.ResourceId.Split('/')[1] -eq 'subscriptions')) {
                    [string] $PolicyAssignmentScope = $PolicyAssignment.ResourceId.Split('/')[4]

                    if ($PolicyAssignmentScope -match $GuidRegex) {
                        [string] $PolicyAssignmentScope = 'Tenant'
                    }
                } else {
                    [string] $PolicyAssignmentScope = $PolicyAssignment.ResourceId.Split('/')[2]
                }

                [string[]] $ResourceType = $PolicyAssignment.ResourceType.Split('/')
                [string] $ResourceFileName = '{0}_{1}-{2}.json' -f $ResourceType[0], $ResourceType[1], $PolicyAssignment.Name

                [pscustomobject] $TemplateObject = @'
                    {
                        "$schema": "",
                        "contentVersion": "1.0.0.0",
                        "parameters": {},
                        "variables": {},
                        "resources": []
                    }
'@ | ConvertFrom-Json

                if ($PolicyAssignmentScope -eq 'Tenant') {
                    [string] $ResourceFilePath = '{0}\.state\{1}' -f $Path, $ResourceFileName
                    [string] $Schema = 'https://schema.management.azure.com/schemas/2019-08-01/managementGroupDeploymentTemplate.json#'
                } else {
                    [AzBuilderScope] $Item = $AzBuilderScope | Where-Object -Property 'Name' -eq $PolicyAssignmentScope
                    [string] $ResourceFilePath = '{0}\{1}\.state\{2}' -f $Path, $Item.Path, $ResourceFileName

                    if ($Item.Scope -eq 'ManagementGroup') {
                        [string] $Schema = 'https://schema.management.azure.com/schemas/2019-08-01/managementGroupDeploymentTemplate.json#'
                    } else {
                        [string] $Schema = 'https://schema.management.azure.com/schemas/2018-05-01/subscriptionDeploymentTemplate.json#'
                    }
                }

                [pscustomobject] $ResourceObject = @'
                    {
                        "type": "Microsoft.Authorization/policyAssignments",
                        "apiVersion": "2020-03-01",
                        "name": "",
                        "properties": {}
                    }
'@ | ConvertFrom-Json

                $ResourceObject.name = $PolicyAssignment.Name
                $ResourceObject.properties = $PolicyAssignment.Properties

                $TemplateObject.'$schema' = $Schema
                $TemplateObject.resources = @($ResourceObject)

                if (-not (Test-Path -Path ($StateFolderPath = Split-Path -Path $ResourceFilePath))) {
                    $null = New-Item -Path $StateFolderPath -ItemType 'Directory'
                }

                $TemplateObject | ConvertTo-Json -Depth 30 | Out-File -FilePath $ResourceFilePath -Force
            }

            [Microsoft.Azure.Commands.Resources.Models.Authorization.PSRoleDefinition[]] $RoleDefinitions = Get-AzRoleDefinition -Custom

            foreach ($RoleDefinition in $RoleDefinitions) {
                if (-not ($RoleDefinition.AssignableScopes[0].Split('/')[1] -eq 'subscriptions')) {
                    [string] $RoleDefinitionScope = $RoleDefinition.AssignableScopes[0].Split('/')[4]

                    if ($RoleDefinitionScope -match $GuidRegex) {
                        [string] $RoleDefinitionScope = 'Tenant'
                    }
                } else {
                    if (-not ($RoleDefinition.AssignableScopes[0].Split('/')[3] -eq 'resourceGroups')) {
                        [string] $RoleDefinitionScope = $RoleDefinition.AssignableScopes[0].Split('/')[2]
                    } else {
                        [string] $RoleDefinitionScope = $RoleDefinition.AssignableScopes[0].Split('/')[4]
                    }
                }

                [string] $ResourceFileName = 'Microsoft.Authorization_roleDefinitions-{0}.json' -f $RoleDefinition.Name

                [pscustomobject] $TemplateObject = @'
                    {
                        "$schema": "",
                        "contentVersion": "1.0.0.0",
                        "parameters": {},
                        "variables": {},
                        "resources": []
                    }
'@ | ConvertFrom-Json

                if ($RoleDefinitionScope -eq 'Tenant') {
                    [string] $ResourceFilePath = '{0}\.state\{1}' -f $Path, $ResourceFileName
                    [string] $Schema = 'https://schema.management.azure.com/schemas/2019-08-01/managementGroupDeploymentTemplate.json#'
                } else {
                    [AzBuilderScope] $Item = $AzBuilderScope | Where-Object -Property 'Name' -eq $RoleDefinitionScope
                    [string] $ResourceFilePath = '{0}\{1}\.state\{2}' -f $Path, $Item.Path, $ResourceFileName

                    if ($Item.Scope -eq 'ManagementGroup') {
                        [string] $Schema = 'https://schema.management.azure.com/schemas/2019-08-01/managementGroupDeploymentTemplate.json#'
                    } elseif ($Item.Scope -eq 'Subscription') {
                        [string] $Schema = 'https://schema.management.azure.com/schemas/2018-05-01/subscriptionDeploymentTemplate.json#'
                    } else {
                        [string] $Schema = 'https://schema.management.azure.com/schemas/2019-04-01/deploymentTemplate.json#'
                    }
                }

                [pscustomobject] $ResourceObject = @'
                    {
                        "type": "Microsoft.Authorization/roleDefinitions",
                        "apiVersion": "2018-01-01-preview",
                        "name": "",
                        "properties": {
                            "roleName": "",
                            "description": "",
                            "permissions": [
                                {
                                    "actions": [],
                                    "notActions": [],
                                    "dataActions": [],
                                    "notDataActions": []
                                }
                            ],
                            "assignableScopes": []
                        }
                    }
'@ | ConvertFrom-Json

                $ResourceObject.name = $RoleDefinition.Name
                $ResourceObject.properties.roleName = $RoleDefinition.Name
                $ResourceObject.properties.description = $RoleDefinition.Description
                $ResourceObject.properties.permissions[0].actions = $RoleDefinition.Actions
                $ResourceObject.properties.permissions[0].notActions = $RoleDefinition.NotActions
                $ResourceObject.properties.permissions[0].dataActions = $RoleDefinition.DataActions
                $ResourceObject.properties.permissions[0].notDataActions = $RoleDefinition.NotDataActions
                $ResourceObject.properties.assignableScopes = $RoleDefinition.AssignableScopes

                $TemplateObject.'$schema' = $Schema
                $TemplateObject.resources = @($ResourceObject)

                if (-not (Test-Path -Path ($StateFolderPath = Split-Path -Path $ResourceFilePath))) {
                    $null = New-Item -Path $StateFolderPath -ItemType 'Directory'
                }

                $TemplateObject | ConvertTo-Json -Depth 30 | Out-File -FilePath $ResourceFilePath -Force
            }

            [Microsoft.Azure.Commands.Resources.Models.Authorization.PSRoleAssignment[]] $RoleAssignments = Get-AzRoleAssignment

            foreach ($RoleAssignment in $RoleAssignments) {
                if (-not ($RoleAssignment.Scope.Split('/')[1] -eq 'subscriptions')) {
                    [string] $RoleAssignmentScope = $RoleAssignment.Scope.Split('/')[4]

                    if ($RoleAssignmentScope -match $GuidRegex) {
                        [string] $RoleAssignmentScope = 'Tenant'
                    }
                } else {
                    if (-not ($RoleAssignment.Scope.Split('/')[3] -eq 'resourceGroups')) {
                        [string] $RoleAssignmentScope = $RoleAssignment.Scope.Split('/')[2]
                    } else {
                        [string] $RoleAssignmentScope = $RoleAssignment.Scope.Split('/')[4]
                    }

                }

                [string] $ResourceFileName = 'Microsoft.Authorization_roleAssignments-{0}.json' -f $RoleAssignment.DisplayName

                [pscustomobject] $TemplateObject = @'
                    {
                        "$schema": "",
                        "contentVersion": "1.0.0.0",
                        "parameters": {},
                        "variables": {},
                        "resources": []
                    }
'@ | ConvertFrom-Json

                if ($RoleDefinitionScope -eq 'Tenant') {
                    [string] $ResourceFilePath = '{0}\.state\{1}' -f $Path, $ResourceFileName
                    [string] $Schema = 'https://schema.management.azure.com/schemas/2019-08-01/managementGroupDeploymentTemplate.json#'
                } else {
                    [AzBuilderScope] $Item = $AzBuilderScope | Where-Object -Property 'Name' -eq $RoleAssignmentScope
                    [string] $ResourceFilePath = '{0}\{1}\.state\{2}' -f $Path, $Item.Path, $ResourceFileName

                    if ($Item.Scope -eq 'ManagementGroup') {
                        [string] $Schema = 'https://schema.management.azure.com/schemas/2019-08-01/managementGroupDeploymentTemplate.json#'
                    } elseif ($Item.Scope -eq 'Subscription') {
                        [string] $Schema = 'https://schema.management.azure.com/schemas/2018-05-01/subscriptionDeploymentTemplate.json#'
                    } else {
                        [string] $Schema = 'https://schema.management.azure.com/schemas/2019-04-01/deploymentTemplate.json#'
                    }
                }

                [pscustomobject] $ResourceObject = @'
                    {
                        "type": "Microsoft.Authorization/roleAssignments",
                        "apiVersion": "2020-04-01-preview",
                        "name": "",
                        "scope": "",
                        "properties": {
                            "roleDefinitionId": "",
                            "principalId": "",
                            "principalType": "",
                            "canDelegate": "",
                            "description": "",
                            "condition": "",
                            "conditionVersion": ""
                        }
                    }
'@ | ConvertFrom-Json

                $ResourceObject.name = $RoleAssignment.DisplayName
                $ResourceObject.scope = $RoleAssignment.Scope
                $ResourceObject.properties.roleDefinitionId = $RoleAssignment.RoleDefinitionId
                $ResourceObject.properties.principalId = $RoleAssignment.ObjectId
                $ResourceObject.properties.principalType = $RoleAssignment.ObjectType
                $ResourceObject.properties.canDelegate = $RoleAssignment.CanDelegate
                $ResourceObject.properties.description = $RoleAssignment.Description
                $ResourceObject.properties.condition = $RoleAssignment.Condition
                $ResourceObject.properties.conditionVersion = $RoleAssignment.ConditionVersion

                $TemplateObject.'$schema' = $Schema
                $TemplateObject.resources = @($ResourceObject)

                if (-not (Test-Path -Path ($StateFolderPath = Split-Path -Path $ResourceFilePath))) {
                    $null = New-Item -Path $StateFolderPath -ItemType 'Directory'
                }

                $TemplateObject | ConvertTo-Json -Depth 30 | Out-File -FilePath $ResourceFilePath -Force
            }

            [Microsoft.Azure.Commands.Blueprint.Models.PSBlueprint[]] $Blueprints = Get-AzBlueprint

            foreach ($Blueprint in $Blueprints) {

                if (-not ($Blueprint.Scope.Split('/')[1] -eq 'subscriptions')) {
                    [string] $BlueprintScope = $Blueprint.Scope.Split('/')[4]

                    if ($BlueprintScope -match $GuidRegex) {
                        [string] $BlueprintScope = 'Tenant'
                    }
                } else {
                    [string] $BlueprintScope = $Blueprint.Scope.Split('/')[2]
                }

                [string] $ResourceFileName = 'Microsoft.Blueprint_blueprints-{0}.json' -f $Blueprint.Name

                [pscustomobject] $TemplateObject = @'
                    {
                        "$schema": "",
                        "contentVersion": "1.0.0.0",
                        "parameters": {},
                        "variables": {},
                        "resources": []
                    }
'@ | ConvertFrom-Json

                if ($BlueprintScope -eq 'Tenant') {
                    [string] $ResourceFilePath = '{0}\.state\{1}' -f $Path, $ResourceFileName
                    [string] $Schema = 'https://schema.management.azure.com/schemas/2019-08-01/managementGroupDeploymentTemplate.json#'
                } else {
                    [AzBuilderScope] $Item = $AzBuilderScope | Where-Object -Property 'Name' -eq $BlueprintScope
                    [string] $ResourceFilePath = '{0}\{1}\.state\{2}' -f $Path, $Item.Path, $ResourceFileName

                    if ($Item.Scope -eq 'ManagementGroup') {
                        [string] $Schema = 'https://schema.management.azure.com/schemas/2019-08-01/managementGroupDeploymentTemplate.json#'
                    } else {
                        [string] $Schema = 'https://schema.management.azure.com/schemas/2018-05-01/subscriptionDeploymentTemplate.json#'
                    }
                }

                [pscustomobject] $ResourceObject = @'
                    {
                        "type": "Microsoft.Blueprint/blueprints",
                        "apiVersion": "2018-11-01-preview",
                        "name": "",
                        "properties": {
                            "displayName": "",
                            "description": "",
                            "targetScope": "",
                            "parameters": {},
                            "resourceGroups": {},
                            "versions": {},
                            "layout": {}
                        },
                        "resources": []
                    }
'@ | ConvertFrom-Json

                $ResourceObject.name = $Blueprint.Name
                $ResourceObject.properties.displayName = $Blueprint.Name
                $ResourceObject.properties.description = $Blueprint.Description
                $ResourceObject.properties.targetScope = $Blueprint.TargetScope
                $ResourceObject.properties.parameters = $Blueprint.Parameters
                $ResourceObject.properties.resourceGroups = $Blueprint.ResourceGroups
                $ResourceObject.properties.versions = $Blueprint.Versions
                $ResourceObject.properties.layout = $Blueprint.ConditionVersion

                if (Test-Path -Path $TemporaryPath) {
                    $null = Remove-Item -Path $TemporaryPath -Recurse -Force
                }

                $null = New-Item -Path $TemporaryPath -ItemType 'Directory'

                $null = Export-AzBlueprintWithArtifact -Blueprint $Blueprint -OutputPath $TemporaryPath

                [string] $BlueprintArtifactsPath = '{0}\{1}\Artifacts' -f $TemporaryPath, $Blueprint.Name
                [System.IO.FileInfo[]] $ArtifactTemplates = Get-ChildItem -Path $BlueprintArtifactsPath -Filter '*.json'

                if ($ArtifactTemplates) {
                    [System.Collections.Generic.List[pscustomobject]] $ArtifactsList = @()

                    foreach ($TemplateFile in $ArtifactTemplates) {
                        [pscustomobject] $ArtifactResourceObject = @'
                            {
                                "type": "artifacts",
                                "apiVersion": "2018-11-01-preview",
                                "name": "",
                                "kind": "",
                                "dependsOn": [],
                                "properties": {}
                            }
'@ | ConvertFrom-Json

                        [pscustomobject] $ArtifactObject = Get-Content -Path $TemplateFile.FullName | ConvertFrom-Json

                        $ArtifactResourceObject.name = $TemplateFile.BaseName
                        $ArtifactResourceObject.kind = $ArtifactObject.kind
                        $ArtifactResourceObject.dependsOn = @($ResourceObject.name)
                        $ArtifactResourceObject.properties = $ArtifactObject.properties

                        $ArtifactsList.Add($ArtifactResourceObject)
                    }

                    $ResourceObject.resources = $ArtifactsList
                }

                $TemplateObject.'$schema' = $Schema
                $TemplateObject.resources = @($ResourceObject)

                if (-not (Test-Path -Path ($StateFolderPath = Split-Path -Path $ResourceFilePath))) {
                    $null = New-Item -Path $StateFolderPath -ItemType 'Directory'
                }

                $TemplateObject | ConvertTo-Json -Depth 30 | Out-File -FilePath $ResourceFilePath -Force

                if (Test-Path -Path $TemporaryPath) {
                    $null = Remove-Item -Path $TemporaryPath -Recurse -Force
                }
            }

            foreach ($Item in ($AzBuilderScope | Where-Object -FilterScript {$_.Scope -eq 'ResourceGroup' -and $_.Parent -eq $Subscription.Id})) {
                [Microsoft.Azure.Commands.ResourceManager.Cmdlets.SdkModels.PSResource[]] $Resources = Get-AzResource -ResourceGroupName $Item.Name

                foreach ($Resource in $Resources) {
                    [string[]] $ResourceType = $Resource.Type.Split('/')
                    [string] $ResourceFileName = '{0}_{1}-{2}.json' -f $ResourceType[0], $ResourceType[1], $Resource.Name
                    [string] $ResourceFilePath = '{0}\{1} ({2})\.state\{3}' -f $Path, $Item.Path, $Item.Location, $ResourceFileName

                    $null = Export-AzResourceGroup -Resource $Resource.Id -Path $ResourceFilePath -ResourceGroupName $Resource.ResourceGroupName -SkipAllParameterization -Force
                }
            }
        }
    } catch {
        $PSCmdlet.ThrowTerminatingError($PSItem)
    }
}
