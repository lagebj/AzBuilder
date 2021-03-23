# AzBuilder

AzBuilder is a PowerShell module that enables you to manage your Azure infrastructure using a "Bring-Your-Own-ARM-Template" approach. It allows you to organize the template files in a folder hierarchy adapted to your business context.

## How it works

### Folder structure

The folder structure is read by AzBuilder and it interpretes the hierarchy based on this. For AzBuilder to be successfult in interpreting the hierarchy, there are a couple of rules to follow:

- Folders representing subscriptions must be named the same as the subscription ID it represents.
    - Example subscription folder name: `b8701a61-1dad-42cc-92db-caa52415ca8c`
- Folders representing resource groups must have the resource group location in parenthesis in the folder name.
    - Example resource group folder name: `rg-mgmt (westeurope)`

AzBuilder interpretes the folder structure in the following manner:

- The root folder is interpreted as the default "Tenant Root Group".
- Any folders containing a GUID is considered a subscription representation.
- Any folder containing parenthesis is considered a resource group representation.

AzBuilder checks current Azure environment and verifies if management groups and resource groups exists. If management groups and/or resource groups defined in the hierarchy does not exist in Azure, these are automatically deployed.

#### Example folder structure

📦c:\temp\AzBuilder-root
 ┣ 📂azb
 ┃ ┣ 📂azb-decommissioned
 ┃ ┣ 📂azb-landingzones
 ┃ ┃ ┣ 📂azb-corp
 ┃ ┃ ┃ ┗ 📂b6d0fd4f-30b4-4cc4-88dd-39d84c5d881a
 ┃ ┃ ┃ ┃ ┗ 📂rg-app (westeurope)
 ┃ ┃ ┗ 📂azb-online
 ┃ ┣ 📂azb-platform
 ┃ ┃ ┣ 📂azb-connectivity
 ┃ ┃ ┣ 📂azb-identity
 ┃ ┃ ┗ 📂azb-management
 ┃ ┃ ┃ ┣ 📂1fb67e23-8f99-41e9-99bf-33236d129fba
 ┃ ┃ ┃ ┃ ┣ 📂rg-mgmt (northeurope)
 ┃ ┃ ┃ ┃ ┃ ┣ 📜solution_AgentHealthAssessment.json
 ┃ ┃ ┃ ┃ ┃ ┗ 📜solution_AgentHealthAssessment.parameters.json
 ┃ ┃ ┃ ┣ 📜policyAssignment_Deploy-LogAnalytics.json
 ┃ ┃ ┃ ┣ 📜policyAssignment_Deploy-LogAnalytics.parameters.json
 ┃ ┃ ┃ ┣ 📜roleAssignment_Deploy-LogAnalytics.json
 ┃ ┃ ┃ ┗ 📜roleAssignment_Deploy-LogAnalytics.parameters.json
 ┃ ┣ 📂azb-sandboxes
 ┃ ┣ 📜policyDefinition_Deploy-ASC-Standard.json
 ┃ ┣ 📜policyDefinition_Deploy-ASC-Standard.parameters.json
 ┃ ┣ 📜policyDefinition_Deploy-LogAnalytics.json
 ┗ ┗ 📜policyDefinition_Deploy-LogAnalytics.parameters.json

In the example above, the root folder is `c:\temp\AzBuilder-root` and is considered as `Tenant Root Group`. The folder `azb` is considered a management group and subfolders `azb-decommissioned`, `azb-landingzones`, `azb-platform` and `azb-sandboxes` are considered child management groups to `azb`.

Folders `azb-corp` and `azb-online` are considered child management groups to `azb-landingzones` and `azb-connectivity`, `azb-identity` and `azb-management` are considered child management groups to `azb-platform`.

Folders `b6d0fd4f-30b4-4cc4-88dd-39d84c5d881a` and `1fb67e23-8f99-41e9-99bf-33236d129fba` represents two different subscriptions and are child subscriptions to `azb-corp` and `azb-management` respectively.

Folders `rg-app (westeurope)` and `rg-mgmt (northeurope)` represents resource groups in subscriptions `b6d0fd4f-30b4-4cc4-88dd-39d84c5d881a` and `1fb67e23-8f99-41e9-99bf-33236d129fba`.

The ARM templates in the example will be provisioned at the scope they are represented in the hierarchy. That means that templates `policyDefinition_Deploy-ASC-Standard.json` and `policyDefinition_Deploy-LogAnalytics.json` will be deployed to management group `azb`. Template files `policyAssignment_Deploy-LogAnalytics.json` and `roleAssignment_Deploy-LogAnalytics.json` will be deployed to management group `azb-management`. Template `solution_AgentHealthAssessment.json` will be deployed to resource group `rg-mgmt`.

### ARM templates

AzBuilder parses all template files in the hierarchy and deploys them at their respective scope. It expects to have a parameters.json file accompanying all templates and skips any templates that does not have an accompanying parameters.json file. The parameters.json file does not need to have any parameters specified.

#### Dependencies

You can specify dependencies to resources that will be deployed at the same scope in the same operation by specifying the template file name without the `.json` extension.

Example
```
"dependsOn": [
    "policyAssignment_Deploy-LogAnalytics"
]
```

## Getting Started

Install from the PSGallery and Import the module

    Install-Module AzBuilder
    Import-Module AzBuilder

## Limitations

- AzBuilder does not support creation of subscriptions. This means that subsciptions will have to be created by other means before AzBuilder can be used to deploy resources at subscription or resource group level. The module is built using a personal Visual Studio subscription and automatic subscription creation is not supported for this type of account, so I have not been able to develop this. Any contribution to this would be greatly appreciated.


## More Information

For more information

* [AzBuilder.readthedocs.io](http://AzBuilder.readthedocs.io)
* [github.com/lagebj/AzBuilder](https://github.com/lagebj/AzBuilder)

This project was generated using [Lage Berger Jensen](https://twitter.com/lageberger)'s [Plastered Plaster Template](https://github.com/lagebj/PlasterTemplates/tree/master/Plastered).
