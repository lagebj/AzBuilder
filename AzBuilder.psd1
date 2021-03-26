# Module manifest for module 'AzBuilder'
# Generated by: Lage Berger Jensen
# Generated on: 04.03.2021

@{
    RootModule        = 'AzBuilder.psm1'
    ModuleVersion     = '0.2.0'
    GUID              = 'd730c1d2-10ae-43f7-bc90-c1b822b2c46e'
    Author            = 'Lage Berger Jensen'
    CompanyName       = ''
    Copyright         = 'Lage Berger Jensen'
    Description       = 'Module to manage hierarchical Azure deployment.'
    FunctionsToExport = @(
        'Build-Template',
        'Invoke-Deployment',
        'Move-Template'
    )
    CmdletsToExport   = @()
    VariablesToExport = @()
    AliasesToExport   = @()
    # CompatiblePSEditions = @()
    PowerShellVersion = '5.1'
    # PowerShellHostName = ''
    # PowerShellHostVersion = ''
    # DotNetFrameworkVersion = ''
    # CLRVersion = ''
    # ProcessorArchitecture = ''
    RequiredModules = @(
        'Az.Resources'
    )
    # RequiredAssemblies = @()
    # ScriptsToProcess = @()
    # TypesToProcess = @()
    # FormatsToProcess = @()
    # NestedModules = @()
    # DscResourcesToExport = @()
    # ModuleList = @()
    # FileList = @()
    PrivateData       = @{
        PSData = @{
            Tags = @(
                'Azure',
                'ARM',
                'Deployment',
                'ResourceManager',
                'Hierarchical',
                'Pipeline',
                'CI/CD',
                'DevOps'
            )
            LicenseUri = 'https://github.com/lagebj/AzBuilder/blob/master/LICENSE'
            ProjectUri = 'https://github.com/lagebj/AzBuilder'
            # IconUri = ''
            ReleaseNotes = @'
                * Added functionality to add deployment delay template by depending on DeploymentDealy_<number of iterations>.
                * Added DeploymentLocation parameter to Invoke-AzBuilderDeployment and Build-AzBuilderTemplate.
'@
        }
    }
    # HelpInfoURI = ''
    DefaultCommandPrefix = 'AzBuilder'
}
