#-------------------------------------------------------
function Convert-MDLinks {
    [CmdletBinding()]
    param(
        [string[]]$Path
    )

    $mdlinkpattern = '(?<link>!?\[(?<label>[^\]]*)\]\((?<target>[^\)]+)\))'
    $reflinkpattern = '(?<link>!?\[(?<label>[^\]]*)\]\[(?<ref>[^\[\]]+)\])'
    $refpattern = '(?<refdef>\[(?<ref>[^\[\]]+)\]:\s(?<target>.+))'

    $Path = Get-Item $Path # resolve wildcards

    foreach ($filename in $Path) {
        $mdfile = Get-Item $filename

        #Search for all the link types
        $mdlinks = Select-String -Path $mdfile -Pattern $mdlinkpattern -AllMatches
        $reflinks = Select-String -Path $mdfile -Pattern $reflinkpattern -AllMatches
        $refdefs = Select-String -Path $mdfile -Pattern $refpattern -AllMatches

        Write-Verbose ('{0}/{1}: {2} links' -f $mdfile.Directory.Name, $mdfile.Name, $mdlinks.count)
        Write-Verbose ('{0}/{1}: {2} ref links' -f $mdfile.Directory.Name, $mdfile.Name, $reflinks.count)
        Write-Verbose ('{0}/{1}: {2} ref defs' -f $mdfile.Directory.Name, $mdfile.Name, $refdefs.count)

        function GetMDLinks {
            foreach ($mdlink in $mdlinks.Matches) {
                $linkitem = [pscustomobject]([ordered]@{
                    mdlink  = ''
                    target  = ''
                    ref     = ''
                    label   = ''
                })
                switch ($mdlink.Groups) {
                    {$_.Name -eq 'link'}   { $linkitem.mdlink = $_.Value }
                    {$_.Name -eq 'target'} { $linkitem.target = $_.Value }
                    {$_.Name -eq 'label'}  { $linkitem.label  = $_.Value }
                }
                $linkitem
            }

            foreach ($reflink in $reflinks.Matches) {
                $linkitem = [pscustomobject]([ordered]@{
                    mdlink  = ''
                    target  = ''
                    ref     = ''
                    label   = ''
                })
                switch ($reflink.Groups) {
                    {$_.Name -eq 'link'}  { $linkitem.mdlink = $_.Value }
                    {$_.Name -eq 'label'} { $linkitem.label  = $_.Value }
                    {$_.Name -eq 'ref'}   { $linkitem.ref    = $_.Value }
                }
                $linkitem
            }
        }

        function GetRefTargets {
            foreach ($refdef in $refdefs.Matches) {
                $refitem = [pscustomobject]([ordered]@{
                    refdef  = ''
                    target  = ''
                    ref     = ''
                })

                switch ($refdef.Groups) {
                    {$_.Name -eq 'refdef'} { $refitem.refdef = $_.Value }
                    {$_.Name -eq 'target'} { $refitem.target = $_.Value }
                    {$_.Name -eq 'ref'}    { $refitem.ref    = $_.Value }
                }
                if (!$RefTargets.ContainsKey($refitem.ref)) {
                    $RefTargets.Add(
                        $refitem.ref,
                        [pscustomobject]@{
                            target = $refitem.target
                            ref    = $refitem.ref
                            refdef = $refitem.refdef
                        }
                    )
                }
            }
        }

        $linkdata = GetMDLinks
        $RefTargets = @{}; GetRefTargets

        # map targets by reference
        if ($RefTargets.Count -gt 0) {
            for ($x=0; $x -lt $linkdata.Count; $x++) {
                foreach ($key in $RefTargets.Keys) {
                    if ($RefTargets[$key].ref -eq $linkdata[$x].ref) {
                        $linkdata[$x].target = $RefTargets[$key].target
                    }
                }
            }
        }

        # Get unique list of targets
        $targets = $linkdata.target + $RefTargets.Values.target | Sort-Object -Unique

        # Calculate new links and references
        $newlinks = @()
        for ($x=0; $x -lt $linkdata.Count; $x++) {
            $newlinks += '[{0:d2}]: {1}' -f ($targets.IndexOf($linkdata[$x].target)+1), $linkdata[$x].target

            $parms = @{
                InputObject = $linkdata[$x]
                MemberType = 'NoteProperty'
                Name = 'newlink'
                Value = '[{0}][{1:d2}]' -f $linkdata[$x].label, ($targets.IndexOf($linkdata[$x].target)+1)
            }
            Add-Member @parms
        }
        #$linkdata

        $mdtext = Get-Content $mdfile
        foreach ($link in $linkdata) {
            $mdtext = $mdtext -replace [regex]::Escape($link.mdlink),$link.newlink
        }
        $mdtext += '<!-- updated link references -->'
        $mdtext += $newlinks | Sort-Object -Unique
        #$mdtext
        Set-Content -Path $mdfile -Value $mdtext -Encoding utf8 -Force
    }
}
#-------------------------------------------------------
function ConvertTo-Contraction {
    [CmdletBinding()]
    param (
        [string[]]$Path,
        [switch]$Recurse
    )

    $contractions = @{
        lower = @{
            '(\s)are(\s)not(\s)'    = "`$1aren't`$3"
            '(\s)cannot(\s)'        = "`$1can't`$2"
            '(\s)could(\s)not(\s)'  = "`$1couldn't`$3"
            '(\s)did(\s)not(\s)'    = "`$1didn't`$3"
            '(\s)do(\s)not(\s)'     = "`$1don't`$3"
            '(\s)does(\s)not(\s)'   = "`$1doesn't`$3"
            '(\s)has(\s)not(\s)'    = "`$1hasn't`$3"
            '(\s)have(\s)not(\s)'   = "`$1haven't`$3"
            '(\s)is(\s)not(\s)'     = "`$1isn't`$3"
            '(\s)it(\s)is(\s)'      = "`$1it's`$3"
            '(\s)should(\s)not(\s)' = "`$1shouldn't`$3"
            '(\s)that(\s)is(\s)'    = "`$1that's`$3"
            '(\s)they(\s)are(\s)'   = "`$1they're`$3"
            '(\s)was(\s)not(\s)'    = "`$1wasn't`$3"
            '(\s)we(\s)are(\s)'     = "`$1we're`$3"
            '(\s)we(\s)have(\s)'    = "`$1we've`$3"
            '(\s)were(\s)not(\s)'   = "`$1weren't`$3"
        }
        upper = @{
            '(\s)Are(\s)not(\s)'    = "`$1Aren't`$3"
            '(\s)Cannot(\s)'        = "`$1Can't`$2"
            '(\s)Could(\s)not(\s)'  = "`$1Couldn't`$3"
            '(\s)Did(\s)not(\s)'    = "`$1Didn't`$3"
            '(\s)Do(\s)not(\s)'     = "`$1Don't`$3"
            '(\s)Does(\s)not(\s)'   = "`$1Doesn't`$3"
            '(\s)Has(\s)not(\s)'    = "`$1Hasn't`$3"
            '(\s)Have(\s)not(\s)'   = "`$1Haven't`$3"
            '(\s)Is(\s)not(\s)'     = "`$1Isn't`$3"
            '(\s)It(\s)is(\s)'      = "`$1It's`$3"
            '(\s)Should(\s)not(\s)' = "`$1Shouldn't`$3"
            '(\s)That(\s)is(\s)'    = "`$1That's`$3"
            '(\s)They(\s)are(\s)'   = "`$1They're`$3"
            '(\s)Was(\s)not(\s)'    = "`$1Wasn't`$3"
            '(\s)We(\s)are(\s)'     = "`$1We're`$3"
            '(\s)We(\s)have(\s)'    = "`$1We've`$3"
            '(\s)Were(\s)not(\s)'   = "`$1Weren't`$3"
        }
    }

    foreach ($filepath in $path) {
        Get-ChildItem $filepath -Recurse:$Recurse | ForEach-Object {
            Write-Host $_.name
            $mdtext = Get-Content $_ -Raw
            foreach ($key in $contractions.lower.keys) {
                $mdtext = $mdtext -creplace $key, $contractions.lower[$key]
            }
            foreach ($key in $contractions.upper.keys) {
                $mdtext = $mdtext -creplace $key, $contractions.upper[$key]
            }
            Set-Content -Path $_ -Value $mdtext -Encoding utf8 -Force
        }
    }
}
#-------------------------------------------------------
function Get-ArticleCount {
    $repoPath = $git_repos['PowerShell-Docs'].path
    Push-Location "$repoPath\reference"
    [PSCustomObject]@{
        repo       = 'MicrosoftDocs/PowerShell-Docs'
        reference  = [int](Get-ChildItem .\5.1\, .\7.2\, .\7.3\, .\7.4\ -file -rec |
                        Group-Object Extension |
                        Where-Object { $_.name -in '.md','.yml'} |
                        Measure-Object count -sum).Sum
        conceptual = [int](Get-ChildItem docs-conceptual -file -rec |
                        Group-Object Extension |
                        Where-Object { $_.name -in '.md','.yml'} |
                        Measure-Object count -sum).Sum
    }
    Pop-Location

    $repoPath = $git_repos['PowerShell-Docs-DSC'].path
    Push-Location "$repoPath\dsc"
    $refdocs = (Get-ChildItem docs-conceptual\dsc-1.1\reference,
        docs-conceptual\dsc-2.0\reference  -Filter *.md -rec).count
    [PSCustomObject]@{
        repo       = 'MicrosoftDocs/PowerShell-Docs-DSC'
        reference  = (Get-ChildItem dsc-1.1, dsc-2.0, dsc-3.0 -Filter *.md -rec).count + $refdocs
        conceptual = (Get-ChildItem docs-conceptual -Filter *.md -rec).count - $refdocs
    }
    Pop-Location

    $repoPath = $git_repos['PowerShell-Docs-Modules'].path
    Push-Location "$repoPath\reference"
    $rulesref = (Get-ChildItem docs-conceptual\PSScriptAnalyzer\Rules -Filter *.md -rec).count
    [PSCustomObject]@{
        repo       = 'MicrosoftDocs/PowerShell-Docs-Modules'
        reference  = (Get-ChildItem ps-modules -Filter *.md -rec).count + $rulesref
        conceptual = (Get-ChildItem docs-conceptual -Filter *.md -rec).count - $rulesref
    }
    Pop-Location

    $repoPath = $git_repos['azure-docs-pr'].path
    Push-Location "$repoPath\articles\cloud-shell"
    [PSCustomObject]@{
        repo       = 'MicrosoftDocs/azure-docs-pr:cloud-shell'
        reference  = 0
        conceptual = (Get-ChildItem *.md,*.yml -rec).count
    }
    Pop-Location

    $repoPath = $git_repos['powershell-docs-sdk-dotnet'].path
    Push-Location "$repoPath\dotnet"
    [PSCustomObject]@{
        repo       = 'MicrosoftDocs/powershell-docs-sdk-dotnet'
        reference  = [int](Get-ChildItem *.xml -file -rec |
                        Measure-Object).Count
        conceptual = 0
    }
    Pop-Location

    $repoPath = $git_repos['PowerShell-Docs-archive'].path
    Push-Location "$repoPath\archived-reference"
    [PSCustomObject]@{
        repo       = 'MicrosoftDocs/PowerShell-Docs-archive'
        reference  = [int](Get-ChildItem .\3.0, .\4.0, .\5.0, .\6\, .\7.0, .\7.1\ -file -rec |
                        Group-Object Extension |
                        Where-Object { $_.name -in '.md','.yml'} |
                        Measure-Object count -sum).Sum
        conceptual = [int](Get-ChildItem docs-conceptual -file -rec |
                        Group-Object Extension |
                        Where-Object { $_.name -in '.md','.yml'} |
                        Measure-Object count -sum).Sum
    }
    Pop-Location
}
#-------------------------------------------------------
function Get-ArticleIssueTemplate {
    param(
        [uri]$articleurl
    )
    $meta = Get-HtmlMetaTags $articleurl

    if ($meta.'ms.prod') {
        $product = "* Product: **$($meta.'ms.prod')**"
        if ($meta.'ms.technology') {
            $product += "`r`n* Technology: **$($meta.'ms.technology')**"
        }
    } elseif ($meta.'ms.service') {
        $product = "* Service: **$($meta.'ms.service')**"
        if ($meta.'ms.subservice') {
            $product += "`r`n* Sub-service: **$($meta.'ms.subservice')**"
        }
    }
    $template = @"
---
#### Document Details

⚠ *Do not edit this section. It is required for docs.microsoft.com ➟ GitHub issue linking.*

* ID: $($meta.document_id)
* Version Independent ID: $($meta.'document_version_independent_id')
* Content: [$($meta.title)]($($meta.articleurl))
* Content Source: [$(($meta.original_content_git_url -split '/live/')[-1])]($($meta.original_content_git_url))
$product
* GitHub Login: @$($meta.author)
* Microsoft Alias: **$($meta.'ms.author')**
"@
    $template
}
#-------------------------------------------------------
function Get-DocMetadata {
    param(
        $path = '*.md',
        [switch]$recurse
    )

    $docfxmetadata = (Get-Content .\docfx.json | ConvertFrom-Json -AsHashtable).build.fileMetadata

    Get-ChildItem $path -Recurse:$recurse | ForEach-Object {
        Get-YamlBlock $_.fullname | ConvertFrom-Yaml | Set-Variable temp
        $filemetadata = [ordered]@{
            file                 = $_.fullname -replace '\\', '/'
            author               = ''
            'ms.author'          = ''
            'manager'            = ''
            'ms.date'            = ''
            'ms.prod'            = ''
            'ms.technology'      = ''
            'ms.topic'           = ''
            'title'              = ''
            'keywords'           = ''
            'description'        = ''
            'online version'     = ''
            'external help file' = ''
            'Module Name'        = ''
            'ms.assetid'         = ''
            'Locale'             = ''
            'schema'             = ''
        }
        foreach ($item in $temp.Keys) {
            if ($temp.$item.GetType().Name -eq 'Object[]') {
                $filemetadata.$item = $temp.$item -join ','
            } else {
                $filemetadata.$item = $temp.$item
            }
        }

        foreach ($prop in $docfxmetadata.keys) {
            if ($filemetadata.$prop -eq '') {
                foreach ($key in $docfxmetadata.$prop.keys) {
                    $pattern = ($key -replace '\*\*', '.*') -replace '\.md', '\.md'
                    if ($filemetadata.file -match $pattern) {
                        $filemetadata.$prop = $docfxmetadata.$prop.$key
                        break
                    }
                }
            }
        }
        New-Object -type psobject -prop $filemetadata
    }
}
#-------------------------------------------------------
function Get-DocsUrl {
    param(
        [string]$filepath,
        [switch]$show
    )
    $folders = '5.1', '6', '7.0', '7.1', 'docs-conceptual'
    try {
        $file = Get-Item $filepath -ErrorAction Stop
        $reporoot = (Get-Item (Get-GitStatus).GitDir -Force).Parent.FullName
        $relpath = ($file.FullName -replace [regex]::Escape($reporoot)).Trim('\') -replace '\\', '/'
        $parts = $relpath -split '/'
        if (($parts[0] -ne 'reference') -and ($parts[1] -notin $folders)) {
            Write-Verbose "No docs url published for $filepath"
        } else {
            if ($parts[1] -eq 'docs-conceptual') {
                $url = ($relpath -replace 'reference/docs-conceptual', 'https://docs.microsoft.com/powershell/scripting/').TrimEnd($file.Extension).TrimEnd('.')
            } else {
                $ver = $parts[1]
                $moniker = "?view=powershell-$ver".TrimEnd('.0')
                $url = (($relpath -replace "reference/$ver", 'https://docs.microsoft.com/powershell/module') -replace $file.Extension).TrimEnd('.') + $moniker
            }
            if ($show) {
                Start-Process $url
            } else {
                Write-Output $url
            }
        }
    } catch {
        $_.Exception.ErrorRecord.Exception.Message
    }
}
#-------------------------------------------------------
function Invoke-Pandoc {
    param(
        [string[]]$Path,
        [string]$OutputPath = '.',
        [switch]$Recurse
    )
    $pandocExe = 'C:\Program Files\Pandoc\pandoc.exe'
    Get-ChildItem $Path -Recurse:$Recurse | ForEach-Object {
        $outfile = Join-Path $OutputPath "$($_.BaseName).help.txt"
        $pandocArgs = @(
            '--from=gfm',
            '--to=plain+multiline_tables',
            '--columns=79',
            "--output=$outfile",
            '--quiet'
        )
        Get-ContentWithoutHeader $_ | & $pandocExe $pandocArgs
    }
}
#-------------------------------------------------------
function New-MdHelp {
    param(
        $Module,
        $OutPath
    )
    $parameters = @{
        Module = $Module
        OutputFolder = $OutPath
        AlphabeticParamsOrder = $true
        UseFullTypeName = $true
        WithModulePage = $true
        ExcludeDontShow = $true
        Encoding = [System.Text.Encoding]::UTF8
    }
    New-MarkdownHelp @parameters
}
#-------------------------------------------------------
function Show-Help {
    param(
        [string]$cmd,

        [ValidateSet('5.1', '6', '7', '7.0', '7.1')]
        [string]$version = '7.0',

        [switch]$UseBrowser
    )

    $aboutpath = @(
        'Microsoft.PowerShell.Core\About',
        'Microsoft.PowerShell.Security\About',
        'Microsoft.WsMan.Management\About',
        'PSDesiredStateConfiguration\About',
        'PSReadline\About',
        'PSScheduledJob\About',
        'PSWorkflow\About'
    )

    $repoPath = $git_repos['PowerShell-Docs'].path
    $basepath = "$repoPath\reference"
    if ($version -eq '7') { $version = '7.0' }
    if ($version -eq '5') { $version = '5.1' }

    if ($cmd -like 'about*') {
        foreach ($path in $aboutpath) {
            $cmdlet = ''
            $mdpath = '{0}\{1}\{2}.md' -f $version, $path, $cmd
            if (Test-Path "$basepath\$mdpath") {
                $cmdlet = $cmd
                break
            }
        }
    } else {
        $cmdlet = Get-Command $cmd
        if ($cmdlet.CommandType -eq 'Alias') { $cmdlet = Get-Command $cmdlet.Definition }
        $mdpath = '{0}\{1}\{2}.md' -f $version, $cmdlet.ModuleName, $cmdlet.Name
    }

    if ($cmdlet) {
        if (Test-Path "$basepath\$mdpath") {
            Get-ContentWithoutHeader "$basepath\$mdpath" |
                Show-Markdown -UseBrowser:$UseBrowser
        } else {
            Write-Error "$mdpath not found!"
        }
    } else {
        Write-Error "$cmd not found!"
    }
}
#-------------------------------------------------------
function Swap-WordWrapSettings {
    $settingsfile = "$env:USERPROFILE\AppData\Roaming\Code\User\settings.json"
    $c = Get-Content $settingsfile
    $s = ($c | Select-String -Pattern 'editor.wordWrapColumn', 'reflowMarkdown.preferredLineLength', 'editor.rulers').line
    $n = $s | ForEach-Object {
        if ($_ -match '//') {
            $_ -replace '//'
        } else {
            $_ -replace ' "', ' //"'
        }
    }
    for ($x = 0; $x -lt $s.count; $x++) {
        $c = $c -replace [regex]::Escape($s[$x]), $n[$x]
        #if ($n[$x] -notlike "*//*") {$n[$x]}
    }
    Set-Content -Path $settingsfile -Value $c -Force
}
Set-Alias -Name ww -Value Swap-WordWrapSettings
#-------------------------------------------------------
function Sync-BeyondCompare {
    param([string]$path)
    $gitStatus = Get-GitStatus
    if ($gitStatus) {
        $reponame = $GitStatus.RepoName
    } else {
        'Not a git repo.'
        return
    }
    $repoPath  = $global:git_repos[$reponame].path
    $ops       = Get-Content $repoPath\.openpublishing.publish.config.json | ConvertFrom-Json -Depth 10 -AsHashtable
    $srcPath   = $ops.docsets_to_publish.build_source_folder
    if ($srcPath -eq '.') {$srcPath = ''}
    $basePath  = Join-Path $repoPath $srcPath '\'
    $mapPath   = Join-Path $basePath $ops.docsets_to_publish.monikerPath
    $monikers  = Get-Content $mapPath | ConvertFrom-Json -Depth 10 -AsHashtable
    $startPath = (Get-Item $path).fullname

    $vlist = $monikers.keys | ForEach-Object { $monikers[$_].packageRoot }
    if ($startpath) {
        $relPath = $startPath -replace [regex]::Escape($basepath)
        $version = ($relPath -split '\\')[0]
        foreach ($v in $vlist) {
            if ($v -ne $version) {
                $target = $startPath -replace [regex]::Escape($version), $v
                if (Test-Path $target) {
                    Start-Process -Wait "${env:ProgramFiles}\Beyond Compare 4\BComp.exe" -ArgumentList $startpath, $target
                }
            }
        }
    } else {
        "Invalid path: $path"
    }
}
Set-Alias bcsync Sync-BeyondCompare
#-------------------------------------------------------
function Sync-VSCode {
    param([string]$path)
    $gitStatus = Get-GitStatus
    if ($gitStatus) {
        $reponame = $GitStatus.RepoName
    } else {
        'Not a git repo.'
        return
    }
    $repoPath  = $global:git_repos[$reponame].path
    $ops       = Get-Content $repoPath\.openpublishing.publish.config.json | ConvertFrom-Json -Depth 10 -AsHashtable
    $srcPath = $ops.docsets_to_publish.build_source_folder
    if ($srcPath -eq '.') {$srcPath = ''}
    $basePath  = Join-Path $repoPath $srcPath '\'
    $mapPath   = Join-Path $basePath $ops.docsets_to_publish.monikerPath
    $monikers  = Get-Content $mapPath | ConvertFrom-Json -Depth 10 -AsHashtable
    $startPath = (Get-Item $path).fullname

    $vlist = $monikers.keys | ForEach-Object { $monikers[$_].packageRoot }
    if ($startpath) {
        $relPath = $startPath -replace [regex]::Escape($basepath)
        $version = ($relPath -split '\\')[0]
        foreach ($v in $vlist) {
            if ($v -ne $version) {
                $target = $startPath -replace [regex]::Escape($version), $v
                if (Test-Path $target) {
                    Start-Process -Wait -WindowStyle Hidden 'code' -ArgumentList '--diff', '--wait', '--reuse-window', $startpath, $target
                }
            }
        }
    } else {
        "Invalid path: $path"
    }
}
Set-Alias vscsync Sync-VSCode
#-------------------------------------------------------
