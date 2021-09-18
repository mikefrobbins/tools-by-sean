# Module manifest for module 'sdwheeler.SystemUtils'
# Generated by: Sean D. Wheeler <sewhee@microsoft.com>
# Generated on: 9/10/2021
@{
    RootModule        = '.\sdwheeler.SystemUtils.psm1'
    ModuleVersion     = '1.0.0'
    GUID              = '28710aa7-3458-4ffe-934c-32759454bbc2'
    Author            = 'Sean D. Wheeler <sewhee@microsoft.com>'
    CompanyName       = 'Microsoft'
    Copyright         = '(c) Microsoft. All rights reserved.'
    # Description = ''
    # PowerShellVersion = ''
    # RequiredModules = @()
    # RequiredAssemblies = @()
    # ScriptsToProcess = @()
    # TypesToProcess = @()
    # FormatsToProcess = @()
    # NestedModules = @()
    FunctionsToExport = @(
        'Get-KBArticle',
        'List-MUHistory',
        'Get-ErrorCode',
        'Get-TcpStatus',
        'Get-User32Reason',
        'Get-RestartEvents',
        'Get-LogonEvents'
    )
    CmdletsToExport   = '*'
    VariablesToExport = '*'
    AliasesToExport   = '*'
    # List of all files packaged with this module
    # FileList = @()
    # HelpInfoURI = ''
    PrivateData       = @{
        PSData = @{
            # Tags = @()
            # LicenseUri = ''
            # ProjectUri = ''
            # IconUri = ''
            # ReleaseNotes = ''
            # Prerelease = ''
            # RequireLicenseAcceptance = $false
            # ExternalModuleDependencies = @()
        } # End of PSData hashtable
    } # End of PrivateData hashtable
}