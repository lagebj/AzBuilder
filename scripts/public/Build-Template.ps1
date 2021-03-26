function Build-Template {
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Low')]
    [OutputType([void])]

    Param (
        [Parameter(Mandatory)]
        [ValidateScript({Test-Path -Path $_}, ErrorMessage = 'Path {0} does not exist. Please specify a valid path.')]
        [string] $InputPath,

        [Parameter(Mandatory)]
        [string] $OutputPath,

        [Parameter()]
        [string] $DeploymentLocation = 'westeurope'
    )

    if (-not $PSBoundParameters.ContainsKey('ErrorAction')) { [System.Management.Automation.ActionPreference] $ErrorActionPreference = [System.Management.Automation.ActionPreference]::Stop }
    if (-not $PSBoundParameters.ContainsKey('InformationAction')) { [System.Management.Automation.ActionPreference] $InformationPreference = [System.Management.Automation.ActionPreference]::Continue }
    if (-not $PSBoundParameters.ContainsKey('Verbose')) { [System.Management.Automation.ActionPreference] $VerbosePreference = $PSCmdlet.SessionState.PSVariable.GetValue('VerbosePreference') } else { [bool] $Verbose = $true }
    if (-not $PSBoundParameters.ContainsKey('Confirm')) { [System.Management.Automation.ActionPreference] $ConfirmPreference = $PSCmdlet.SessionState.PSVariable.GetValue('ConfirmPreference') }
    if (-not $PSBoundParameters.ContainsKey('WhatIf')) { [System.Management.Automation.ActionPreference] $WhatIfPreference = $PSCmdlet.SessionState.PSVariable.GetValue('WhatIfPreference') }

    if ($PSCmdlet.ShouldProcess($InputPath, 'Builds ARM templates')) {
        try {
            if ($InputPath.EndsWith([System.IO.Path]::DirectorySeparatorChar)) {
                [string] $InputPath = $InputPath.TrimEnd([System.IO.Path]::DirectorySeparatorChar)
            }

            if ($OutputPath.EndsWith([System.IO.Path]::DirectorySeparatorChar)) {
                [string] $OutputPath = $OutputPath.TrimEnd([System.IO.Path]::DirectorySeparatorChar)
            }

            if (Test-Path -Path $OutputPath) {
                $null = Remove-Item -Path $OutputPath -Recurse -Force
            }

            $null = New-Item -Path $OutputPath -ItemType 'Directory'

            [System.Collections.Generic.List[AzBuilderScope]] $AzBuilderScope = EnumerateStructure $InputPath

            [pscustomobject[]] $ManagementGroupDeployments = InitializeManagementGroupTemplate $AzBuilderScope $OutputPath
            if ($ManagementGroupDeployments) {
                foreach ($Deployment in $ManagementGroupDeployments) {
                    'Template for deployment {0} has been created and contains resources: {1}.' -f $Deployment.DeploymentName, ($Deployment.Resources -join ', ')
                }
            }

            [pscustomobject[]] $SubscriptionDeployments = InitializeSubscriptionTemplate $AzBuilderScope $OutputPath
            if ($SubscriptionDeployments) {
                foreach ($Deployment in $SubscriptionDeployments) {
                    'Template for deployment {0} has been created and contains resources: {1}' -f $Deployment.DeploymentName, ($Deployment.Resources -join ', ')
                }
            }

            [pscustomobject[]] $ResourceGroupDeployments = InitializeResourceGroupTemplate $AzBuilderScope $OutputPath
            if ($ResourceGroupDeployments) {
                foreach ($Deployment in $ResourceGroupDeployments) {
                    'Template for deployment {0} has been created and contains resources: {1}' -f $Deployment.DeploymentName, ($Deployment.Resources -join ', ')
                }
            }

            [pscustomobject[]] $ResourceDeployments = InitializeResourceTemplate $AzBuilderScope $OutputPath $DeploymentLocation
            if ($ResourceDeployments) {
                foreach ($Deployment in $ResourceDeployments) {
                    'Template for deployment {0} has been created and contains resources: {1}' -f $Deployment.DeploymentName, ($Deployment.Resources -join ', ')
                }
            }
        } catch {
            $PSCmdlet.ThrowTerminatingError($PSItem)
        }
    }
}
