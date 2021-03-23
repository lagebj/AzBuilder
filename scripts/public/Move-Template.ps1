function Move-Template {
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Low')]
    [OutputType([void])]

    Param (
        [Parameter(Mandatory)]
        [pscustomobject[]] $Deployments,

        [Parameter(Mandatory)]
        [ValidateScript({Test-Path -Path $_}, ErrorMessage = 'Path {0} does not exist. Please specify a valid path.')]
        [string] $Path
    )

    if (-not $PSBoundParameters.ContainsKey('ErrorAction')) { [System.Management.Automation.ActionPreference] $ErrorActionPreference = [System.Management.Automation.ActionPreference]::Stop }
    if (-not $PSBoundParameters.ContainsKey('InformationAction')) { [System.Management.Automation.ActionPreference] $InformationPreference = [System.Management.Automation.ActionPreference]::Continue }
    if (-not $PSBoundParameters.ContainsKey('Verbose')) { [System.Management.Automation.ActionPreference] $VerbosePreference = $PSCmdlet.SessionState.PSVariable.GetValue('VerbosePreference') } else { [bool] $Verbose = $true }
    if (-not $PSBoundParameters.ContainsKey('Confirm')) { [System.Management.Automation.ActionPreference] $ConfirmPreference = $PSCmdlet.SessionState.PSVariable.GetValue('ConfirmPreference') }
    if (-not $PSBoundParameters.ContainsKey('WhatIf')) { [System.Management.Automation.ActionPreference] $WhatIfPreference = $PSCmdlet.SessionState.PSVariable.GetValue('WhatIfPreference') }

    if ($PSCmdlet.ShouldProcess($InputPath, 'Builds ARM templates')) {
        try {
            if ($Path.EndsWith([System.IO.Path]::DirectorySeparatorChar)) {
                [string] $Path = $Path.TrimEnd([System.IO.Path]::DirectorySeparatorChar)
            }

            [System.IO.DirectoryInfo[]] $Directories = Get-ChildItem -Path $Path -Recurse -Directory

            foreach ($Deployment in $Deployments) {
                if ($Deployment.Scope -eq 'Tenant') {
                    [System.Collections.Generic.List[string]] $FilesToMove = @()
                    [string] $TenantPath = $Path
                    [string] $TenantDeploymentsPath = '{0}\.deployments' -f $TenantPath

                    if ($TenantDeploymentsPath) {
                        if (-not (Test-Path -Path $TenantDeploymentsPath)) {
                            $null = New-Item -Path $TenantDeploymentsPath -ItemType 'Directory'
                        }
                    }

                    [Microsoft.Azure.Commands.ResourceManager.Cmdlets.SdkModels.PSDeployment[]] $TenantDeployments = Get-AzTenantDeployment

                    foreach ($NestedDeploymentName in $Deployment.Outputs) {
                        [Microsoft.Azure.Commands.ResourceManager.Cmdlets.SdkModels.PSDeployment] $NestedDeployment = $TenantDeployments | Where-Object -Property 'DeploymentName' -eq $NestedDeploymentName

                        if ($NestedDeployment) {
                            if ($NestedDeployment.ProvisioningState -eq 'Succeeded') {
                                [string] $TemplateFile = '{0}\{1}.json' -f $TenantPath, $NestedDeploymentName.Replace('AzBuilder.', '')
                                [string] $TemplateParametersFile = '{0}\{1}.parameters.json' -f $TenantPath, $NestedDeploymentName.Replace('AzBuilder.', '')

                                if (Test-Path -Path $TemplateFile) {
                                    $FilesToMove.Add($TemplateFile)
                                }

                                if (Test-Path -Path $TemplateParametersFile) {
                                    $FilesToMove.Add($TemplateParametersFile)
                                }
                            }
                        }
                    }

                    [string[]] $FilesToMove = $FilesToMove

                    if ($FilesToMove) {
                        $null = Move-Item -Path $FilesToMove -Destination $TenantDeploymentsPath -Force
                    }
                } elseif ($Deployment.Scope -eq 'ManagementGroup') {
                    [System.Collections.Generic.List[string]] $FilesToMove = @()
                    [string] $ManagementGroupPath = $Directories | Where-Object -Property 'BaseName' -eq $Deployment.Parent | Select-Object -ExpandProperty 'FullName'
                    [string] $ManagementGroupDeploymentsPath = '{0}\.deployments' -f $ManagementGroupPath

                    if ($ManagementGroupDeploymentsPath) {
                        if (-not (Test-Path -Path $ManagementGroupDeploymentsPath)) {
                            $null = New-Item -Path $ManagementGroupDeploymentsPath -ItemType 'Directory'
                        }
                    }

                    [Microsoft.Azure.Commands.ResourceManager.Cmdlets.SdkModels.PSDeployment[]] $ManagementGroupDeployments = Get-AzManagementGroupDeployment -ManagementGroupId $Deployment.Parent

                    foreach ($NestedDeploymentName in $Deployment.Outputs) {
                        [Microsoft.Azure.Commands.ResourceManager.Cmdlets.SdkModels.PSDeployment] $NestedDeployment = $ManagementGroupDeployments | Where-Object -Property 'DeploymentName' -eq $NestedDeploymentName

                        if ($NestedDeployment) {
                            if ($NestedDeployment.ProvisioningState -eq 'Succeeded') {
                                [string] $TemplateFile = '{0}\{1}.json' -f $ManagementGroupPath, $NestedDeploymentName.Replace('AzBuilder.', '')
                                [string] $TemplateParametersFile = '{0}\{1}.parameters.json' -f $ManagementGroupPath, $NestedDeploymentName.Replace('AzBuilder.', '')

                                if (Test-Path -Path $TemplateFile) {
                                    $FilesToMove.Add($TemplateFile)
                                }

                                if (Test-Path -Path $TemplateParametersFile) {
                                    $FilesToMove.Add($TemplateParametersFile)
                                }
                            }
                        }
                    }

                    [string[]] $FilesToMove = $FilesToMove

                    if ($FilesToMove) {
                        $null = Move-Item -Path $FilesToMove -Destination $ManagementGroupDeploymentsPath -Force
                    }
                } elseif ($Deployment.Scope -eq 'Subscription') {
                    [System.Collections.Generic.List[string]] $FilesToMove = @()
                    [string] $SubscriptionPath = $Directories | Where-Object -Property 'BaseName' -eq $Deployment.Parent | Select-Object -ExpandProperty 'FullName'
                    [string] $SubscriptionDeploymentsPath = '{0}\.deployments' -f $SubscriptionPath

                    if ($SubscriptionDeploymentsPath) {
                        if (-not (Test-Path -Path $SubscriptionDeploymentsPath)) {
                            $null = New-Item -Path $SubscriptionDeploymentsPath -ItemType 'Directory'
                        }
                    }

                    [Microsoft.Azure.Commands.ResourceManager.Cmdlets.SdkModels.PSDeployment[]] $SubscriptionDeployments = Get-AzDeployment

                    foreach ($NestedDeploymentName in $Deployment.Outputs) {
                        [Microsoft.Azure.Commands.ResourceManager.Cmdlets.SdkModels.PSDeployment] $NestedDeployment = $SubscriptionDeployments | Where-Object -Property 'DeploymentName' -eq $NestedDeploymentName

                        if ($NestedDeployment) {
                            if ($NestedDeployment.ProvisioningState -eq 'Succeeded') {
                                [string] $TemplateFile = '{0}\{1}.json' -f $SubscriptionPath, $NestedDeploymentName.Replace('AzBuilder.', '')
                                [string] $TemplateParametersFile = '{0}\{1}.parameters.json' -f $SubscriptionPath, $NestedDeploymentName.Replace('AzBuilder.', '')

                                if (Test-Path -Path $TemplateFile) {
                                    $FilesToMove.Add($TemplateFile)
                                }

                                if (Test-Path -Path $TemplateParametersFile) {
                                    $FilesToMove.Add($TemplateParametersFile)
                                }
                            }
                        }
                    }

                    [string[]] $FilesToMove = $FilesToMove

                    if ($FilesToMove) {
                        $null = Move-Item -Path $FilesToMove -Destination $SubscriptionDeploymentsPath -Force
                    }
                } elseif ($Deployment.Scope -eq 'ResourceGroup') {
                    [System.Collections.Generic.List[string]] $FilesToMove = @()
                    [regex] $ResourceGroupRegex = [regex]::new('(?i)(.+)(?:\()([a-zA-Z]+)(?:\))')
                    [System.IO.DirectoryInfo[]] $ResourceGroupDirectories = $Directories | Where-Object -Property 'BaseName' -Match $ResourceGroupRegex

                    foreach ($Directory in $ResourceGroupDirectories) {
                        [System.Text.RegularExpressions.Match] $MatchItem = $ResourceGroupRegex.Match($Directory.BaseName)

                        if ($MatchItem.Groups[1].Value.Trim() -eq $Deployment.Parent) {
                            [string] $ResourceGroupPath = $Directory.FullName
                            [string] $ResourceGroupDeploymentsPath = '{0}\.deployments' -f $ResourceGroupPath
                        }
                    }

                    if ($ResourceGroupDeploymentsPath) {
                        if (-not (Test-Path -Path $ResourceGroupDeploymentsPath)) {
                            $null = New-Item -Path $ResourceGroupDeploymentsPath -ItemType 'Directory'
                        }
                    }

                    [Microsoft.Azure.Commands.ResourceManager.Cmdlets.SdkModels.PSResourceGroupDeployment[]] $ResourceGroupDeployments = Get-AzResourceGroupDeployment -ResourceGroupName $Deployment.Parent

                    foreach ($NestedDeploymentName in $Deployment.Outputs) {
                        [Microsoft.Azure.Commands.ResourceManager.Cmdlets.SdkModels.PSResourceGroupDeployment] $NestedDeployment = $ResourceGroupDeployments | Where-Object -Property 'DeploymentName' -eq $NestedDeploymentName

                        if ($NestedDeployment) {
                            if ($NestedDeployment.ProvisioningState -eq 'Succeeded') {
                                [string] $TemplateFile = '{0}\{1}.json' -f $ResourceGroupPath, $NestedDeploymentName.Replace('AzBuilder.', '')
                                [string] $TemplateParametersFile = '{0}\{1}.parameters.json' -f $ResourceGroupPath, $NestedDeploymentName.Replace('AzBuilder.', '')

                                if (Test-Path -Path $TemplateFile) {
                                    $FilesToMove.Add($TemplateFile)
                                }

                                if (Test-Path -Path $TemplateParametersFile) {
                                    $FilesToMove.Add($TemplateParametersFile)
                                }
                            }
                        }
                    }

                    [string[]] $FilesToMove = $FilesToMove

                    if ($FilesToMove) {
                        $null = Move-Item -Path $FilesToMove -Destination $ResourceGroupDeploymentsPath -Force
                    }
                }
            }
        } catch {
            $PSCmdlet.ThrowTerminatingError($PSItem)
        }
    }
}
