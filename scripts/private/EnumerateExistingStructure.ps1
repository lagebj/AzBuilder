function EnumerateExistingStructure {
    [CmdletBinding()]
    [OutputType([System.Collections.Generic.List[AzBuilderScope]])]

    Param ()

    try {
        [System.Collections.Generic.List[AzBuilderScope]] $AzBuilderList = @()
        [System.Collections.Generic.List[string]] $SubscriptionsInManagementGroups = @()

        [Microsoft.Azure.Commands.Profile.Models.PSAzureTenant] $Tenant = Get-AzTenant
        [Microsoft.Azure.Commands.Resources.Models.ManagementGroups.PSManagementGroupInfo[]] $ManagementGroups = Get-AzManagementGroup
        [Microsoft.Azure.Commands.Profile.Models.PSAzureSubscription[]] $Subscriptions = Get-AzSubscription | Where-Object -Property 'State' -eq 'Enabled'


        if ($ManagementGroups) {
            foreach ($ManagementGroupName in $ManagementGroups.Name) {
                [Microsoft.Azure.Commands.Resources.Models.ManagementGroups.PSManagementGroup] $ManagementGroup = Get-AzManagementGroup -GroupName $ManagementGroupName -Expand -Recurse

                if ($ManagementGroup.Name -ne $Tenant.Id) {
                    if ($ManagementGroup.ParentName -eq $Tenant.Id) {
                        [string] $ManagementGroupPath = $ManagementGroup.Name
                    } else {
                        [Microsoft.Azure.Commands.Resources.Models.ManagementGroups.PSManagementGroup] $ParentManagementGroup = Get-AzManagementGroup -GroupName $ManagementGroup.ParentName -Expand -Recurse

                        if ($ParentManagementGroup.ParentName -eq $Tenant.Id) {
                            [string] $ManagementGroupPath = '{0}\{1}' -f $ManagementGroup.ParentName, $ManagementGroup.Name
                        } else {
                            [string] $ManagementGroupPath = '{0}\{1}' -f $ManagementGroup.ParentName, $ManagementGroup.Name

                            do {
                                [string] $ManagementGroupPath = '{0}\{1}' -f $ParentManagementGroup.ParentName, $ManagementGroupPath

                                [Microsoft.Azure.Commands.Resources.Models.ManagementGroups.PSManagementGroup] $ParentManagementGroup = Get-AzManagementGroup -GroupName $ParentManagementGroup.ParentName -Expand -Recurse
                            } while (-not ($ParentManagementGroup.ParentName -eq $Tenant.Id))
                        }
                    }

                    [AzBuilderScope] $AzBuilderScope = [AzBuilderScope]::new($ManagementGroup.Name, 'ManagementGroup', $ManagementGroupPath)
                    $AzBuilderScope.ParentId = $ManagementGroups | Where-Object -Property 'Name' -eq $ManagementGroup.ParentName | Select-Object -ExpandProperty 'Id'
                    $AzBuilderList.Add($AzBuilderScope)

                    foreach ($Subscription in $Subscriptions) {
                        if (($ManagementGroup.Children.Name -contains $Subscription.Name) -or ($ManagementGroup.Children.Name -contains $Subscription.Id)) {
                            [string] $SubscriptionPath = '{0}\{1}' -f $ManagementGroupPath, $Subscription.Id

                            [AzBuilderScope] $AzBuilderScope = [AzBuilderScope]::new($Subscription.Id, 'Subscription', $SubscriptionPath)
                            $AzBuilderScope.ParentId = $ManagementGroups | Where-Object -Property 'Name' -eq $ManagementGroup.Name | Select-Object -ExpandProperty 'Id'
                            $AzBuilderList.Add($AzBuilderScope)

                            $SubscriptionsInManagementGroups.Add($Subscription.Id)

                            $null = Set-AzContext -SubscriptionObject $Subscription

                            [Microsoft.Azure.Commands.ResourceManager.Cmdlets.SdkModels.PSResourceGroup[]] $ResourceGroups = Get-AzResourceGroup

                            foreach ($ResourceGroup in $ResourceGroups) {
                                [string] $ResourceGroupPath = '{0}\{1}' -f $SubscriptionPath, $ResourceGroup.ResourceGroupName

                                [AzBuilderScope] $AzBuilderScope = [AzBuilderScope]::new($ResourceGroup.ResourceGroupName, 'ResourceGroup', $ResourceGroupPath, $ResourceGroup.Location)
                                $AzBuilderScope.ParentId = '/subscriptions/{0}' -f $Subscription.Id
                                $AzBuilderList.Add($AzBuilderScope)
                            }
                        }
                    }
                }
            }
        }

        foreach ($Subscription in $Subscriptions) {
            if (-not ($SubscriptionsInManagementGroups -contains $Subscription.Id)) {
                [AzBuilderScope] $AzBuilderScope = [AzBuilderScope]::new($Subscription.Id, 'Subscription', $Subscription.Id)
                $AzBuilderScope.ParentId = $ManagementGroups | Where-Object -Property 'Name' -eq $Tenant.Id | Select-Object -ExpandProperty 'Id'
                $AzBuilderList.Add($AzBuilderScope)
            }
        }

        return $AzBuilderList
    } catch {
        $PSCmdlet.ThrowTerminatingError($PSItem)
    }
}
