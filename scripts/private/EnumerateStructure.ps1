function EnumerateStructure {
    [CmdletBinding()]
    [OutputType([System.Collections.Generic.List[AzBuilderScope]])]

    Param (
        [Parameter(Mandatory, Position = 0)]
        [string] $Path
    )

    try {
        [regex] $SubscriptionRegex = [regex]::new('(?i)[a-z0-9]{8}-([a-z0-9]{4}-){3}[a-z0-9]{12}')
        [regex] $LocationRegex = [regex]::new('(?i)(.+)(?:\()([a-zA-Z]+)(?:\))')

        [System.IO.DirectoryInfo] $Root = Get-Item -Path $Path
        [System.Collections.Generic.List[AzBuilderScope]] $AzBuilderList = @()
        [System.IO.FileInfo[]] $Templates = $Root.GetFiles('*.json')

        if ($Templates) {
            [AzBuilderScope] $RootScope = [AzBuilderScope]::new('Tenant Root Group', 'Tenant', $Root.FullName)
            $RootScope.Templates = GetTemplates $Templates
        }

        foreach ($RootItem in ($Root.GetDirectories() | Where-Object -Property 'Name' -ne '.deployments')) {
            if ($RootItem.BaseName -match $SubscriptionRegex) {
                [string] $Scope = 'Subscription'
                [string] $RootItemName = $SubscriptionRegex.Match($RootItem.BaseName).Groups[0].Value
            } else {
                [string] $Scope = 'ManagementGroup'
                [string] $RootItemName = $RootItem.Name
            }

            [AzBuilderScope] $RootAzBuilderScope = [AzBuilderScope]::new($RootItemName, $Scope, ('{0}' -f $RootItem.FullName.ToLower().Replace(('{0}\' -f $Path.ToLower()), '')))
            $AzBuilderList.Add($RootAzBuilderScope)

            foreach ($ChildPath in $RootAzBuilderScope.Path) {
                [System.IO.DirectoryInfo[]] $Children = Get-ChildItem -Path ('{0}\{1}' -f $Path, $ChildPath) -Recurse -Directory

                foreach ($ChildItem in ($Children | Where-Object -Property 'Name' -ne '.deployments')) {
                    [string] $Location = [string]::Empty

                    if ($ChildItem.BaseName -match $SubscriptionRegex) {
                        [string] $Scope = 'Subscription'
                        [string] $ChildItemName = $SubscriptionRegex.Match($ChildItem.BaseName).Groups[0].Value
                    } elseif ($ChildItem.Parent -match $SubscriptionRegex) {
                        [string] $Scope = 'ResourceGroup'
                        [string] $ChildItemName = $LocationRegex.Match($ChildItem.BaseName).Groups[1].Value.Trim()
                        [string] $Location = $LocationRegex.Match($ChildItem.BaseName).Groups[2].Value
                    } else {
                        [string] $Scope = 'ManagementGroup'
                        [string] $ChildItemName = $ChildItem.Name
                    }

                    [AzBuilderScope] $ChildAzBuilderScope = [AzBuilderScope]::new($ChildItemName, $Scope, ('{0}' -f $ChildItem.FullName.ToLower().Replace(('{0}\' -f $Path.ToLower()), '')), $Location)
                    $AzBuilderList.Add($ChildAzBuilderScope)
                }
            }
        }

        [Microsoft.Azure.Commands.Resources.Models.ManagementGroups.PSManagementGroupInfo[]] $ManagementGroups = Get-AzManagementGroup
        [Microsoft.Azure.Commands.Profile.Models.PSAzureSubscription[]] $Subscriptions = Get-AzSubscription
        [System.Collections.Generic.List[Microsoft.Azure.Commands.ResourceManager.Cmdlets.SdkModels.PSResourceGroup]] $ResourceGroups = @()

        for ($i = 0; $i -lt $AzBuilderList.Count; $i++) {
            [System.IO.DirectoryInfo] $Item = Get-Item -Path ('{0}\{1}' -f $Path, $AzBuilderList[$i].Path)
            [System.IO.FileInfo[]] $Templates = $Item.GetFiles('*.json')

            if ($Templates) {
                $AzBuilderList[$i].Templates = GetTemplates $Templates
            }

            if ($AzBuilderList[$i].Scope -eq 'Tenant') {
                $AzBuilderList[$i].ParentId = $ManagementGroups | Where-Object -Property 'DisplayName' -eq $AzBuilderList[$i].Name | Select-Object -ExpandProperty 'Id'
            } elseif ($AzBuilderList[$i].Scope -eq 'ManagementGroup') {
                if (-not ($ManagementGroups.DisplayName -contains $AzBuilderList[$i].Name)) {
                    $AzBuilderList[$i].Deploy = $true
                }

                if ($ManagementGroups.DisplayName -contains $AzBuilderList[$i].Parent) {
                    $AzBuilderList[$i].ParentId = $ManagementGroups | Where-Object -Property 'DisplayName' -eq $AzBuilderList[$i].Parent | Select-Object -ExpandProperty 'Id'
                }
            } elseif ($AzBuilderList[$i].Scope -eq 'Subscription') {
                if ($Subscriptions.Id -contains $AzBuilderList[$i].Name) {
                    $AzBuilderList[$i].ParentId = $ManagementGroups | Where-Object -Property 'DisplayName' -eq $AzBuilderList[$i].Parent | Select-Object -ExpandProperty 'Id'

                    $null = Set-AzContext -Subscription $AzBuilderList[$i].Name

                    [Microsoft.Azure.Commands.ResourceManager.Cmdlets.SdkModels.PSResourceGroup[]] $ExistingResourceGroups = Get-AzResourceGroup

                    foreach ($ResourceGroup in $ExistingResourceGroups) {
                        $ResourceGroups.Add($ResourceGroup)
                    }
                }
            }
        }

        for ($i = 0; $i -lt $AzBuilderList.Count; $i++) {
            if ($AzBuilderList[$i].Scope -eq 'ResourceGroup') {
                if (-not ($ResourceGroups.ResourceGroupName -contains $AzBuilderList[$i].Name)) {
                    $AzBuilderList[$i].Deploy = $true
                }

                $AzBuilderList[$i].ParentId = '/subscriptions/{0}' -f $AzBuilderList[$i].Parent
            }
        }

        $AzBuilderList.Add($RootScope)

        return $AzBuilderList
    } catch {
        $PSCmdlet.ThrowTerminatingError($PSItem)
    }
}
