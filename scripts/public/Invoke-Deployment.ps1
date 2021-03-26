function Invoke-Deployment {
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Low')]
    [OutputType([pscustomobject[]])]

    Param (
        [Parameter(Mandatory)]
        [ValidateScript({Test-Path -Path $_}, ErrorMessage = 'Path {0} does not exist. Please specify a valid path.')]
        [string] $Path,

        [Parameter()]
        [string] $DeploymentLocation = 'westeurope'
    )

    if (-not $PSBoundParameters.ContainsKey('ErrorAction')) { [System.Management.Automation.ActionPreference] $ErrorActionPreference = [System.Management.Automation.ActionPreference]::Stop }
    if (-not $PSBoundParameters.ContainsKey('InformationAction')) { [System.Management.Automation.ActionPreference] $InformationPreference = [System.Management.Automation.ActionPreference]::Continue }
    if (-not $PSBoundParameters.ContainsKey('Verbose')) { [System.Management.Automation.ActionPreference] $VerbosePreference = $PSCmdlet.SessionState.PSVariable.GetValue('VerbosePreference') } else { [bool] $Verbose = $true }
    if (-not $PSBoundParameters.ContainsKey('Confirm')) { [System.Management.Automation.ActionPreference] $ConfirmPreference = $PSCmdlet.SessionState.PSVariable.GetValue('ConfirmPreference') }
    if (-not $PSBoundParameters.ContainsKey('WhatIf')) { [System.Management.Automation.ActionPreference] $WhatIfPreference = $PSCmdlet.SessionState.PSVariable.GetValue('WhatIfPreference') }

    if ($PSCmdlet.ShouldProcess($Path, 'Deploys all ARM templates')) {
        try {
            [System.IO.DirectoryInfo] $Root = Get-Item -Path $Path
            [System.IO.FileInfo[]] $Templates = $Root.GetFiles('*.json')
            [System.Collections.Generic.List[pscustomobject]] $Deployments = @()
            [regex] $DeploymentsRegex = [regex]::new('(?is)\[.*\]')

            if ($Templates) {
                [System.IO.FileInfo[]] $ManagementGroupTemplates = $Templates | Where-Object -Property 'BaseName' -like 'AzBuilder.Deploy.ManagementGroups_*'
                [System.IO.FileInfo[]] $SubscriptionTemplates = $Templates | Where-Object -Property 'BaseName' -like 'AzBuilder.Move.Subscriptions_*'

                if ($ManagementGroupTemplates) {
                    foreach ($Template in $ManagementGroupTemplates) {
                        'Deploying template {0}' -f $Template.Name
                        $Deployment = New-AzTenantDeployment -Location $DeploymentLocation -TemplateFile $Template.FullName

                        [pscustomobject] $DeploymentDetails = [pscustomobject] @{
                            Scope = 'Tenant'
                            Parent = $null
                            DeploymentName = $Deployment.DeploymentName
                            Outputs = ($DeploymentsRegex.Match($Deployment.OutputsString)).Value | ConvertFrom-Json
                        }

                        $Deployments.Add($DeploymentDetails)
                    }
                }

                if ($SubscriptionTemplates) {
                    foreach ($Template in $SubscriptionTemplates) {
                        'Deploying template {0}' -f $Template.Name
                        $Deployment = New-AzTenantDeployment -Location $DeploymentLocation -TemplateFile $Template.FullName

                        [pscustomobject] $DeploymentDetails = [pscustomobject] @{
                            Scope = 'Tenant'
                            Parent = $null
                            DeploymentName = $Deployment.DeploymentName
                            Outputs = ($DeploymentsRegex.Match($Deployment.OutputsString)).Value | ConvertFrom-Json
                        }

                        $Deployments.Add($DeploymentDetails)
                    }
                }
            }

            [System.IO.DirectoryInfo[]] $TemplateDirectories = $Root.GetDirectories() | Where-Object -Property 'Name' -ne '.deployments'

            if ($TemplateDirectories) {
                [System.IO.DirectoryInfo] $RootManagementGroupDirectory = $TemplateDirectories | Where-Object -Property 'BaseName' -eq 'managementgroups'
                [System.IO.DirectoryInfo] $RootSubscriptionDirectory = $TemplateDirectories | Where-Object -Property 'BaseName' -eq 'subscriptions'

                if ($RootManagementGroupDirectory) {
                    [System.IO.DirectoryInfo[]] $ManagementGroupDirectories = $RootManagementGroupDirectory.GetDirectories()

                    if ($ManagementGroupDirectories) {
                        foreach ($ManagementGroupDirectory in $ManagementGroupDirectories) {
                            [System.IO.FileInfo[]] $Templates = $ManagementGroupDirectory.GetFiles('*.json')

                            if ($Templates) {
                                foreach ($Template in $Templates) {
                                    'Deploying template {0}' -f $Template.Name
                                    $Deployment = New-AzManagementGroupDeployment -ManagementGroupId $ManagementGroupDirectory.BaseName -Location $DeploymentLocation -TemplateFile $Template.FullName

                                    [pscustomobject] $DeploymentDetails = [pscustomobject] @{
                                        Scope = 'ManagementGroup'
                                        Parent = $Deployment.ManagementGroupId
                                        DeploymentName = $Deployment.DeploymentName
                                        Outputs = ($DeploymentsRegex.Match($Deployment.OutputsString)).Value | ConvertFrom-Json
                                    }

                                    $Deployments.Add($DeploymentDetails)
                                }
                            }
                        }
                    }
                }

                if ($RootSubscriptionDirectory) {
                    [System.IO.DirectoryInfo[]] $SubscriptionDirectories = $RootSubscriptionDirectory.GetDirectories()

                    if ($SubscriptionDirectories) {
                        foreach ($SubscriptionDirectory in $SubscriptionDirectories) {
                            $null = Set-AzContext -Subscription $SubscriptionDirectory.BaseName

                            [System.IO.FileInfo[]] $Templates = $SubscriptionDirectory.GetFiles('*.json')

                            if ($Templates) {
                                foreach ($Template in $Templates) {
                                    'Deploying template {0}' -f $Template.Name
                                    $Deployment = New-AzDeployment -Location $DeploymentLocation -TemplateFile $Template.FullName

                                    [pscustomobject] $DeploymentDetails = [pscustomobject] @{
                                        Scope = 'Subscription'
                                        Parent = $Deployment.Id.Split('/')[2]
                                        DeploymentName = $Deployment.DeploymentName
                                        Outputs = ($DeploymentsRegex.Match($Deployment.OutputsString)).Value | ConvertFrom-Json
                                    }

                                    $Deployments.Add($DeploymentDetails)
                                }
                            }

                            [System.IO.DirectoryInfo[]] $ResourceGroupDirectories = $SubscriptionDirectory.GetDirectories()

                            if ($ResourceGroupDirectories) {
                                foreach ($ResourceGroupDirectory in $ResourceGroupDirectories) {
                                    [System.IO.FileInfo[]] $Templates = $ResourceGroupDirectory.GetFiles('*.json')

                                    if ($Templates) {
                                        foreach ($Template in $Templates) {
                                            'Deploying template {0}' -f $Template.Name
                                            $Deployment = New-AzResourceGroupDeployment -ResourceGroupName $ResourceGroupDirectory.BaseName -TemplateFile $Template.FullName -Mode 'Incremental'

                                            [pscustomobject] $DeploymentDetails = [pscustomobject] @{
                                                Scope = 'ResourceGroup'
                                                Parent = $Deployment.ResourceGroupName
                                                DeploymentName = $Deployment.DeploymentName
                                                Outputs = ($DeploymentsRegex.Match($Deployment.OutputsString)).Value | ConvertFrom-Json
                                            }

                                            $Deployments.Add($DeploymentDetails)
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }

            [pscustomobject[]] $Deployments = $Deployments

            return $Deployments
        } catch {
            $PSCmdlet.ThrowTerminatingError($PSItem)
        }
    }
}
