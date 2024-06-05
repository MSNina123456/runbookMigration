# runbook migration cross tenants

.SYNOPSIS 

    This PowerShell script migrate runbooks and variables cross tenants 

.DESCRIPTION

    This PowerShell script is designed to migrate runbooks and variables cross tenants, you could run it in local PS window, all PS 5 and PS 7 runbooks will be imported as PS 5 runtime, you could change it via runtime environment later.

.PARAMETER oldSubscriptionId

    Required. Source subscription of the Azure Automation account.

.PARAMETER newSubscriptionId

    Required. Target subscription of the Azure Automation account.
 
.PARAMETER oldRGName

    Required. The name of the source resource group of the Azure Automation account.
    
.PARAMETER newRGName

    Required. The name of the target resource group of the Azure Automation account.

.PARAMETER oldAAName

    Required. The name of the Azure Automation account under source subscription.

.PARAMETER newAAName

    Required. The name of the Azure Automation account under target subscription.

.PARAMETER tempFolder

    Required. Temporary folder to store all runbook scripts, you could delete it once migration is done.

.NOTES

    AUTHOR: Nina Li
    LASTEDIT: May 23, 2024

.example

    .\RunbookMigration.ps1 -oldSubscriptionId <source sub id> -newSubscriptionId <target sub id> -oldRGName <source resource group name> -oldAAName <source AA name> -newRGName <target resource group name> -newAAName <target AA name> -tempFolder <temp folder path>
