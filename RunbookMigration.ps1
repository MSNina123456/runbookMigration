<#
.SYNOPSIS 
    This PowerShell script migrate runbooks and variables cross tenants 

.DESCRIPTION

    This PowerShell script is designed to migrate runbooks and variables cross tenants, all PS 5 and PS 7 runbooks will be imported as PS 5 runtime, you could change it via runtime environment later.

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

    example: .\RunbookMigration.ps1 -oldSubscriptionId <source sub id> -newSubscriptionId <target sub id> -oldRGName <source resource group name> -oldAAName <source AA name> -newRGName <target resource group name> -newAAName <target AA name> -tempFolder <temp folder path>
#>

param (
    [Parameter(Mandatory = $true)]
    [string]$oldSubscriptionId,

    [Parameter(Mandatory = $true)]
    [string]$newSubscriptionId,

    [Parameter(Mandatory = $true)]
    [string]$oldRGName,

    [Parameter(Mandatory = $true)]
    [string]$newRGName,

    [Parameter(Mandatory = $true)]
    [string]$oldAAName,

    [Parameter(Mandatory = $true)]
    [string]$newAAName,

    [Parameter(Mandatory = $true)]
    [string]$tempFolder
)

$ErrorActionPreference = "SilentlyContinue"

$global:varList=@()

function enableScriptExecution
{
    Write-Host "Setting script execution policy to unrestricted."

    try
    {
		$execp = Get-ExecutionPolicy

        if(-not($execp -eq "Unrestricted") -and -not($execp -contains 'Bypass'))
        {
            if(-not($force) -and -not($PSCmdlet.ShouldContinue(("Your current policy " + $execp +" is not executable policy, so the script cannot be loaded, see details https://docs.microsoft.com/en-us/powershell/module/microsoft.powershell.security/set-executionpolicy?view=powershell-7.2."), "Would you still like to set execution policy with unrestricted?")))
            {
                Write-Host "User has chosen to reject this request, skipping log collection, please set execution policy to bypass or unrestricted before continuing"
                exit
            }
        }

        Set-ExecutionPolicy unrestricted

    }
    catch 
    {
        Write-Error "Failed to set script's execution policy."
    }
}

function loginAzAccount {
    param (
    [Parameter(Mandatory = $true)]
    [string]$subscriptionId
    )

    try
    {
        # This script login to azure by user credential from local powershell window.
        "Logging in to Azure..."
        Connect-AzAccount -SubscriptionId $subscriptionId
	Select-AzSubscription -SubscriptionId $subscriptionId
    }
    catch {
        Write-Error -Message $_.Exception
        throw $_.Exception
    }
}

function init {

    enableScriptExecution

    if ($False -eq (Test-Path $tempFolder) )
    {
        New-Item -Path $tempFolder -ItemType "directory" -Force | Out-Null
    }
}
function exportRunbooks
{
    $runbooks = Get-AzAutomationRunbook -AutomationAccountName $oldAAName -ResourceGroupName $oldRGName

    $runbookList=@()
    foreach ($runbook in $runbooks){
        $runbookName = $runbook.Name
        $runbookType = $runbook.RunbookType
        $scriptFolder = "$tempFolder\$runbookType"
        Write-Host "Exporting runbook: $runbookName"
        if ($False -eq (Test-Path $scriptFolder) )
        {
            New-Item -Path $scriptFolder -ItemType "directory" -Force | Out-Null
        }
        try {  
            
            $export = Export-AzAutomationRunbook -ResourceGroupName $oldRGName -AutomationAccountName $oldAAName -Name $runbookName -OutputFolder $scriptFolder
            $runbookList += @{Name = $runbookName; Type = $runbookType}
        }
        catch {
            Write-Error -Message $_.Exception
            throw $_.Exception
        }
    }
}

function importRunbook
{
    param (
    [Parameter(Mandatory = $true)]
    [string]$path,

    [Parameter(Mandatory = $true)]
    [string[]]$scripts,

    [Parameter(Mandatory = $true)]
    [string]$type
    )

    foreach($script in $scripts)
    {
        try {
            $action = Import-AzAutomationRunbook -Path "$path\$script" -ResourceGroupName $newRGName -AutomationAccountName $newAAName -Type $type
        }
        catch {
            Write-Error -Message $_.Exception
            throw $_.Exception
        }
    }
}
function importRunbooks
{
    $scriptFolder = Get-ChildItem -Path "$tempFolder" -Name -Directory
    foreach ($subfolder in $scriptFolder)
    {
        $script = Get-ChildItem -Path "$tempFolder\$subfolder" -Name
        switch ($subfolder)
        {
            'GraphPowerShellWorkflow'
            {
                'Importing graphical powershell workflow runbooks'
                importRunbook -path "$tempFolder\$subfolder" -scripts $script -type GraphicalPowerShellWorkflow
            }
            'GraphPowerShell'
            {
                'Importing graphical powershell runbooks'
                importRunbook -path "$tempFolder\$subfolder" -scripts $script -type GraphicalPowerShell
            }
            'Script' 
            {
                'Importing powershell workflow runbooks'
                importRunbook -path "$tempFolder\$subfolder" -scripts $script -type PowerShellWorkflow
            }
            'PowerShell' 
            {
                'Importing powershell runbooks'
                importRunbook -path "$tempFolder\$subfolder" -scripts $script -type PowerShell
            }
            'PowerShell7' 
            {
                'Importing powershell 7 runbooks'
                importRunbook -path "$tempFolder\$subfolder" -scripts $script -type PowerShell
            }
            'PowerShell72' 
            {
                'Importing powershell 7.2 runbooks'
                importRunbook -path "$tempFolder\$subfolder" -scripts $script -type PowerShell
            }
            'Python2' 
            {
                'Importing python 2 runbooks'
                importRunbook -path "$tempFolder\$subfolder" -scripts $script -type Python2
            }
            'Python3' 
            {
                'Importing python 3 runbooks'
                importRunbook -path "$tempFolder\$subfolder" -scripts $script -type Python3
            }
        }
    }
}

function exportVar
{
    $Variable = Get-AzAutomationVariable -AutomationAccountName $oldAAName -ResourceGroupName $oldRGName
    foreach ($var in $Variable)
    {
        $global:varList += @{Name = $var.Name; Value = $var.Value; Encry = $var.Encrypted; Des = $var.Description}
    }   
}

function importVar 
{ 
    foreach ($var in $global:varList)
    {
        $varName = $var.Name
        Write-Host "importing variable: $varName"
        $encry = $var.Encry
        $value = $var.Value
        $desc = $var.Des
        try {
            $imp = New-AzAutomationVariable -AutomationAccountName $newAAName -Name $varName -Encrypted $encry -Value $value -Description $desc -ResourceGroupName $newRGName
        }
        catch {
            Write-Error -Message $_.Exception
            throw $_.Exception
        }
        
    }
}

function main
{
    init

    Write-Host "Please verify if you have sufficient permissions to access both old subscription $oldSubscriptionId and new subscription $newSubscriptionId"

    LoginAzAccount -subscriptionId $oldSubscriptionId

    $oldAAinfo = Get-AzAutomationAccount -ResourceGroupName $oldRGName -Name $oldAAName
    if (!$oldAAinfo){
        Write-Host "In your subscription $oldSubscriptionId, Automation account $oldAAName under resource group $oldRGName does not exist, please double check name and restart the script!"
        return
    }
    
    exportRunbooks
    exportVar

    LoginAzAccount -subscriptionId $newSubscriptionId

    $newAAinfo = Get-AzAutomationAccount -ResourceGroupName $newRGName -Name $newAAName
    if (!$newAAinfo){
        Write-Host "In your subscription $newSubscriptionId, Automation account $newAAName under resource group $newRGName does not exist, please double check name and restart the script!"
        return
    }

    importVar
    importRunbooks

    Write-Host "All are done! Please check your automation account $newAAName under subscription $newSubscriptionId and you should be able to find all imported runbooks and variables now!"
}

main
