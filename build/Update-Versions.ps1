<# 
 .SYNOPSIS
 A script to manage version numbers in source controlled files.

 .DESCRIPTION
 This script takes care of updating source file with the appropriate global version numbers
 managed in a central versions.json file. The script can also be used to easily bump version numbers.

 .PARAMETER Path
 The path to the master versions.json file. If not specified, defaults to a file next to the script.

 .PARAMETER Bump
 Optionally increases a given component of the version numbers: Major, Minor, Build, Revision.

 .PARAMETER Suffix
 Optionally update the suffix portion of the version used in packages: alpha, beta, preview, prerelease, rc.

 .PARAMETER ClearSuffix
 Clears any existing suffix in the version used in packages.
#>

param(
    [String]
    $Path, 

    [String]
    [ValidateSet("Major", "Minor", "Build", "Revision")] 
    $Bump,

    [String]
    [ValidateSet("alpha", "beta", "preview", "prerelease", "rc")] 
    $Suffix,

    [Switch]
    $ClearSuffix
);

###############################################################################
# Functions
###############################################################################

function Get-ScriptDirectory() {
    return Split-Path $script:MyInvocation.MyCommand.Path;
}

# Formats JSON in a nicer format than the built-in ConvertTo-Json does.
# See https://github.com/PowerShell/PowerShell/issues/2736
function Format-Json([Parameter(Mandatory, ValueFromPipeline)][String] $json) {
  $indent = 0;
  ($json -Split '\n' |
    % {
      if ($_ -match '[\}\]]') {
        # This line contains  ] or }, decrement the indentation level
        $indent--
      }
      $line = (' ' * $indent * 2) + $_.TrimStart().Replace(':  ', ': ')
      if ($_ -match '[\{\[]') {
        # This line contains [ or {, increment the indentation level
        $indent++
      }
      $line
  }) -Join "`n"
}

# Parses a string representing a version number into an object
function Parse-Version([Parameter(ValueFromPipeline=$true)] $text) {
    $regex = [regex] "(\d+)(?:\.(\d+))?(?:\.(\d+))?(?:\.(\d+))?(?:-(.+))?";
    $match = $regex.Match($text);

    if(!$match.Success)
    {
        throw ("String does not match expected version format: {0}" -f $text);
    }

    $major = $match.Groups[1].Value;
    $minor = $match.Groups[2].Value;
    $build = $match.Groups[3].Value;
    $revision = $match.Groups[4].Value;
    $suffix = $match.Groups[5].Value;

    $major = if($major) { [int] $major } else { $null };
    $minor = if($minor) { [int] $minor } else { $null };
    $build = if($build) { [int] $build } else { $null };
    $revision = if($revision) { [int] $revision } else { $null };
    $suffix = if($suffix) { $suffix } else { $null };

    $version = New-Object psobject;
    $version | Add-Member NoteProperty "Major" $major;
    $version | Add-Member NoteProperty "Minor" $minor;
    $version | Add-Member NoteProperty "Build" $build;
    $version | Add-Member NoteProperty "Revision" $revision;
    $version | Add-Member NoteProperty "Suffix" $suffix;
    return $version;
}

# Outputs a version object to a string
function Out-Version([Parameter(ValueFromPipeline=$true)] $version) {
    $text = "";
    $text += $version.Major;

    if(!($version.Minor -eq $null)) {
        $text += "." + $version.Minor;
    }

    if(!($version.Build -eq $null)) {
        $text += "." + $version.Build;
    }

    if(!($version.Revision -eq $null)) {
        $text += "." + $version.Revision;
    }

    if(!($version.Suffix -eq $null -or $version.Suffix.Length -eq 0)) {
        $text += "-" + $version.Suffix;
    }

    return $text;
}

# Expands a list of paths into fully qualified file paths, doing two things:
# 1) Converting relative paths to an absolute path
# 2) Finding files that match wildcards
function Expand-Files($baseDirectory, $paths) {
    $result = @();

    foreach($path in $paths) {
        if(![System.IO.Path]::IsPathRooted($path)) {
            $path = Join-Path $baseDirectory $path;
        }

        if($path -match "\*") {
            # Need to expand expression into path, use dir
            $expandedPaths = Get-ChildItem $path | %{ $_.FullName };
            $result += $expandedPaths;
        }
        else {
            $result += $path;
        }
    }

    return $result;
}

# Updates the versions in a C# .cs file.
function Update-CSharpFile($path, $versions) {
    $oldContent = [System.IO.File]::ReadAllText($path);
    $newContent = $oldContent;

    $assemblyVersion = $versions.assemblyVersion;
    $assemblyFileVersion = $versions.assemblyFileVersion;

    if($assemblyVersion) {
        $newContent = $newContent -replace "AssemblyVersion\(.*\)", "AssemblyVersion(""$assemblyVersion"")";
    }

    if($assemblyFileVersion) {
        $newContent = $newContent -replace "AssemblyFileVersion\(.*\)", "AssemblyFileVersion(""$assemblyFileVersion"")";
    }
    
    if($newContent -ne $oldContent) {
        Write-Host "Updating versions in $path";
        Set-Content -Path $path -Value $newContent;
    }
    else {
        Write-Warning "Skipping $path, no changes were required";
    }
}

# Updates the versions in an MSBuild project file.
function Update-MSBuildFile($path, $versions) {
    $assemblyVersion = $versions.assemblyVersion;
    $assemblyFileVersion = $versions.assemblyFileVersion;
    $packageVersion = $versions.packageVersion;

    $oldContent = [System.IO.File]::ReadAllText($path);
    $newContent = $oldContent;

    if($assemblyVersion) {
        $newContent = $newContent -replace "<AssemblyVersion>.*</AssemblyVersion>", "<AssemblyVersion>$assemblyVersion</AssemblyVersion>";
    }

    if($assemblyFileVersion) {
        $newContent = $newContent -replace "<FileVersion>.*</FileVersion>", "<FileVersion>$assemblyFileVersion</FileVersion>";
    }

    if($packageVersion) {
        $newContent = $newContent -replace "<Version>.*</Version>", "<Version>$packageVersion</Version>";
    }

    if($newContent -ne $oldContent) {
        Write-Host "Updating versions in $path";
        Set-Content -Path $path -Value $newContent -Encoding UTF8;
    }
    else {
        Write-Warning "Skipping $path, no changes were required";
    }
}

# Updates the versions in a versioned file. Only certain file types are supported.
function Update-VersionedFile($path, $versions) {
    $extension = [System.IO.Path]::GetExtension($path);
    if($extension -imatch "\.cs") {
        Update-CSharpFile $path $versions;
    }
    elseif(@(".props", ".targets", ".csproj") -icontains $extension) {
        Update-MSBuildFile $path $versions;
    }
    else {
        Write-Warning "Skipping $file, the file type is unsupported";
    }
}

# Parses a JSON file containing version information.
function Parse-VersionInfoJsonFile($path) {
    $versionInfo = Get-Content $versionsFile | ConvertFrom-Json;
    return $versionInfo;
}

# Updates the versioned files, applying the version numbers in the 
# corresponding input file.
function Update-VersionedFiles($versionsFile) {
    $versionInfo = Parse-VersionInfoJsonFile $versionsFile;
    $baseDirectory = Split-Path -Parent $versionsFile;

    $versionedFiles = Expand-Files $baseDirectory $versionInfo.versionedFiles;
    foreach($file in $versionedFiles) {
        if(!(Test-Path $file)) {
            Write-Warning "Skipping $file, file does not exist";
        }
        else {
            Update-VersionedFile $file $versionInfo.versions;
        }
    }
}

# Bumps the version component of a given version object, automatically
# resetting smaller components to 0 if a higher component is bumped.
function Bump-Version(
    $version, 

    [ValidateSet("Major", "Minor", "Build", "Revision")] 
    $component
) {
    if($component -eq "Major") {
        if(!($version.Major -eq $null)) {
            $version.Major += 1;
        }
    }
    elseif($component -eq "Minor") {
        if(!($version.Minor -eq $null)) {
            $version.Minor += 1;
        }
    }
    elseif($component -eq "Build") {
        if(!($version.Build -eq $null)) {
            $version.Build += 1;
        }
    }
    elseif($component -eq "Revision") {
        if(!($version.Revision -eq $null)) {
            $version.Revision += 1;
        }
    }

    if($component -eq "Major") {
        if(!($version.Minor -eq $null)) {
            $version.Minor = 0;
        }
    }

    if($component -eq "Major" -or $component -eq "Minor") {
        if(!($version.Build -eq $null)) {
            $version.Build = 0;
        }
    }

    if($component -eq "Major" -or $component -eq "Minor" -or $component -eq "Build") {
        if(!($version.Revision -eq $null)) {
            $version.Revision = 0;
        }
    }

    return $version;
}


# Modifies the versions in a versions.json file, bumping a given version component
# or updating a version suffix.
function Modify-Versions(
    $versionsFile, 
    $bumpComponent,
    $suffix
) {
    $versionInfo = Parse-VersionInfoJsonFile $versionsFile;
    $versions = $versionInfo.versions;

    Write-Host "Updating $versionsFile";

    if($bumpComponent) {
        if($versions.assemblyVersion) {
            if($bumpComponent -eq "Major" -or $bumpComponent -eq "Minor") {
                $oldVersion = $versions.assemblyVersion;
                $version = Parse-Version $versions.assemblyVersion;
                $version = Bump-Version $version $bumpComponent;
                $newVersion = $version | Out-Version;

                if($newVersion -ne $oldVersion) {
                    $versions.assemblyVersion = $newVersion;
                    Write-Host "Updating assemblyVersion from $oldVersion to $newVersion";
                }
            }
        }

        if($versions.assemblyFileVersion) {
            $oldVersion = $versions.assemblyFileVersion;
            $version = Parse-Version $versions.assemblyFileVersion;
            $version = Bump-Version $version $bumpComponent;
            $newVersion = $version | Out-Version;

            if($newVersion -ne $oldVersion) {
                $versions.assemblyFileVersion = $newVersion;
                Write-Host "Updating assemblyFileVersion from $oldVersion to $newVersion";
            }
        }
    }

    if($versions.packageVersion) {
        $oldVersion = $versions.packageVersion;
        $version = Parse-Version $versions.packageVersion;

        if($bumpComponent) {
            $version = Bump-Version $version $bumpComponent;
        }

        if(!($suffix -eq $null)) {
            $version.Suffix = $suffix;
        }

        $newVersion = $version | Out-Version;
        if($newVersion -ne $oldVersion) {
            $versions.packageVersion = $newVersion;
            Write-Host "Updating packageVersion from $oldVersion to $newVersion";
        }
    }

    $json = ConvertTo-Json $versionInfo | Format-Json;
    Set-Content -Path $versionsFile -Value $json;
}

###############################################################################
# Main 
###############################################################################

if(!$Path) {
    # If path was not specified, default to finding the file next to the script
    $scriptDirectory = Get-ScriptDirectory;
    $Path = Join-Path $scriptDirectory "versions.json";
}

if(!(Test-Path -PathType Leaf $Path)) {
    throw "File $Path does not exist";
}

if($Suffix -and $ClearSuffix) {
    throw "You cannot specify both Suffix and ClearSuffix. Please specify only one.";
}

$localSuffix = if($Suffix) { $Suffix } elseif($ClearSuffix) { "" } else { $null };

if($Bump -or !($localSuffix -eq $null)) {
    Modify-Versions $Path $Bump $localSuffix;
}

Update-VersionedFiles $Path;
