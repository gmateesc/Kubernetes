
#
# 1. Disable warnings about unused variables
#

# See
#   https://github.com/PowerShell/PSScriptAnalyzer/issues/1354
#

#Get-Module PSScriptAnalyzer
#Get-Module Diagnostics

#
# 1.1 For a script
#
[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseDeclaredVarsMoreThanAssignments', 'SubscriptionName', Justification='scope')]
[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseDeclaredVarsMoreThanAssignments', 'Region', Justification='scope')]
[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseDeclaredVarsMoreThanAssignments', 'RG', Justification='scope')]
[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseDeclaredVarsMoreThanAssignments', 'AKSCluster', Justification='scope')]
[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseDeclaredVarsMoreThanAssignments', 'ACR_NAME', Justification='scope')]

[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseDeclaredVarsMoreThanAssignments', 'NodeCount', Justification='scope')]

param()


#
# 1.2 For a function
#

# function foo {
#    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseDeclaredVarsMoreThanAssignments', 'unused',
#        Justification = 'Reason why it is a false positive')]
#    param()
#
#    $unused = $null
# }


#
# 2. Define variables
#

$SubscriptionName = "Main subscription"
$Region = "eastus"
$RG = "AKSRG"
#$AKSCluster = "AKS_CLUSTER_ONE"
$AKSCluster = "AKS_CLUSTER_TWO"
$NodeCount = "2"


#$ACR_NAME = "acrusdemo"
#$ACR_NAME = "ACRGABI"
$ACR_NAME = "acrgabi"




#
# 3. Prompt function
#

#function prompt {"PS [$env:COMPUTERNAME]> "}
#function prompt {"PS > "}
function prompt {"PS $ "}

