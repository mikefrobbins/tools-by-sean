# Module manifest for module 'sdwheeler.Themes'
# Generated by: sewhee
# Generated on: 4/16/2024

@{
    RootModule                  = 'sdwheeler.Themes.psm1'
    ModuleVersion               = '0.0.1'
    # CompatiblePSEditions      = @()
    GUID                        = 'f176df32-3e83-4f73-a049-e1ee039d9e4d'
    Author                      = 'sewhee'
    CompanyName                 = 'Microsoft'
    Copyright                   = '(c) sewhee. All rights reserved.'
    Description                 = 'A module for applying colorized themes to the console.'
    PowerShellVersion           = 5.1
    # PowerShellHostName        = ''
    # PowerShellHostVersion     = ''
    # DotNetFrameworkVersion    = ''
    # ClrVersion                = ''
    # ProcessorArchitecture     = ''
    # RequiredModules           = @()
    # RequiredAssemblies        = @()
    # ScriptsToProcess          = @()
    # TypesToProcess            = @()
    FormatsToProcess            = @('sdwheeler.Themes.Format.ps1xml')
    # NestedModules             = @()
    FunctionsToExport           = @(
        'Get-ShellTheme',
        'Set-ShellTheme',
        'Get-VSCodeThemes',
        'Set-VSCodeTheme',
        'Get-WindowsTerminalThemes',
        'Get-WindowsTerminalProfiles',
        'Set-WindowsTerminalTheme'
    )
    CmdletsToExport             = @()
    VariablesToExport           = '*'
    AliasesToExport             = @()
    # DscResourcesToExport      = @()
    # ModuleList                = @()
    # FileList                  = @()
    PrivateData                 = @{
        PSData                           = @{
            # Tags                       = @()
            # LicenseUri                 = ''
            # ProjectUri                 = ''
            # IconUri                    = ''
            # ReleaseNotes               = ''
            # Prerelease                 = ''
            # RequireLicenseAcceptance   = $false
            # ExternalModuleDependencies = @()
        }
    }
    # HelpInfoURI               = ''
    # DefaultCommandPrefix      = ''
}
