class AzBuilderScope {
    [string] $Name

    [ValidateSet('Tenant', 'ManagementGroup', 'Subscription', 'ResourceGroup')]
    [string] $Scope

    hidden [string] $Path

    [pscustomobject[]] $Templates

    [bool] $Deploy = $false

    hidden [string] $Parent

    [string] $ParentId

    [string] $Location

    hidden [regex] $SubscriptionRegex = [regex]::new('(?i)[a-z0-9]{8}-([a-z0-9]{4}-){3}[a-z0-9]{12}')

    AzBuilderScope($Name, $Scope, $Path) {
        $this.Name = $Name
        $this.Scope = $Scope
        $this.Path = $Path

        $this.GetParent()
    }

    AzBuilderScope($Name, $Scope, $Path, $Location) {
        $this.Name = $Name
        $this.Scope = $Scope
        $this.Path = $Path
        $this.Location = $Location

        $this.GetParent()
    }

    hidden [void] GetParent() {
        $SplitPath = $this.Path.Split([System.IO.Path]::DirectorySeparatorChar)

        if ($SplitPath.Count -gt 1) {
            if ($SplitPath[-2] -match $this.SubscriptionRegex) {
                $this.Parent = $this.SubscriptionRegex.Match($SplitPath[-2]).Groups[0].Value
            } else {
                $this.Parent = $SplitPath[-2]
            }
        } else {
            $this.Parent = 'Tenant Root Group'
        }
    }
}