# -------------------------
# Setup
# -------------------------

# 1) define all projects and libraries
$projects = New-Object System.Collections.ArrayList
$projects += [Project]::New($false, "Everywhere Launcher", 	"M:\dev\apps\EverywhereLauncher\app-resources\src\main\res")
$projects += [Project]::New($false, "CoSy\main", 			"M:\dev\apps\CoSy\app\src\main\res")
$projects += [Project]::New($false, "CoSy\facebook", 		"M:\dev\apps\CoSy\app\src\facebook\res")
$projects += [Project]::New($false, "CoSy\whatsapp", 		"M:\dev\apps\CoSy\app\src\whatsapp\res")
$projects += [Project]::New($true, "Backup Manager", 		"M:\dev\libraries\backupManager\src\main\res")

# 2) define all valid string files
$stringFiles = New-Object System.Collections.ArrayList
$stringFiles += "strings.xml"
$stringFiles += "plurals.xml"

# 3) define default and source languages
$defaultLanguage = "en"
$sourceLanguages = New-Object System.Collections.ArrayList
$sourceLanguages += "de"
$sourceLanguages += "en"

# -------------------------
# Variables
# -------------------------

$global:root = Get-Location
$global:debug = $true
$waitForUserInput = $true
$modeOneWaySync = $true

# -------------------------
# Functions
# -------------------------

function DEBUG {
	if ($global:debug) { Write-Host $args }
}

function CreateFolder($folderName) 
{
	$path = "$($global:root)\$folderName"
	if (-not ($path | Test-Path))
	{	
		DEBUG("`n[INFO] Creating folder: $path`n")
		New-Item -ItemType Directory -Force -Path $path | Out-Null
	}
}

function ContainsAnyFile($folder, $files) 
{
	foreach ($f in $files) 
	{
		if ([System.IO.File]::Exists("$folder\$f")) 
		{
			return $true
		}
	}
	
	return $false
}

function LastChangeDate($file)
{
	return (Get-Item $file).LastWriteTime
}

function IsFileNewer($file1, $file2)
{
	$changeDate1 = LastChangeDate $file1
	$changeDate2 = LastChangeDate $file2	
	return $changeDate1 -gt $changeDate2 
}

function CopyFile($pathFrom, $pathTo)
{
	New-Item -Force $pathTo
	Copy-Item $pathFrom $pathTo -Recurse -Force
}

function PrintCopyInfo($copiedToGithub, $copiedToProject)
{
	if (($copiedToGithub -eq 0) -and ($copiedToProject -eq 0)) 
	{ 	
		Write-Host "-    NOTHING COPIED!"
	}
	else
	{
		Write-Host "-    Copied from PROJECT       => app-resources: $copiedToGithub"
		Write-Host "-    Copied from app-resources => PROJECT:       $copiedToProject"
	}
}

# -------------------------
# Script
# -------------------------

Write-Host "`n-------------"
Write-Host "- PROJECTS: $($projects.count)"
Write-Host "-------------"

# 1) create folders for each projects
$projects | ForEach { CreateFolder $_.name }

# 2) load existing languages inside each projects
DEBUG("")
$projects | ForEach { $_.loadLanguages($stringFiles, $defaultLanguage) }
DEBUG("")

# 3) copy all NOT YET existing files from each project to github and vice versa
Write-Host "- 1) Preparing projects"
$copiedToProject = 0
$copiedToGithub = 0
$projects | ForEach { $_.copyFiles($true, $stringFiles, $true, [ref]$copiedToProject, [ref]$copiedToGithub) }
$projects | ForEach { $_.copyFiles($true, $stringFiles, $false, [ref]$copiedToProject, [ref]$copiedToGithub) }
PrintCopyInfo $copiedToGithub $copiedToProject
Write-Host "- 2) Found following $($projects.count) project(s):"
$projects | ForEach { Write-Host "-    $($_.name) - folders: $($_.folders.count)" }

# 4) sync all files between project and github repository
Write-Host "- 3) Synced files"
$copiedToProject = 0
$copiedToGithub = 0
$projects | ForEach { $_.syncProject($stringFiles, $sourceLanguages, $modeOneWaySync, [ref]$copiedToProject, [ref]$copiedToGithub) }
PrintCopyInfo $copiedToGithub $copiedToProject
Write-Host "-------------`n"

# IDEE- Übersetzen via github
# 1) Kopie von englisch machen in richtigem Ordner - eventuell in einem TO_TRANSLATE Ordner?
# 2) Benutzer übersetzt in diesem File
# 3) Kopie von TO_TRANSLATE in richtigen Ordner + alle Texte die gleich sind wie der englische löschen -> Problem: Texte könnten wirklich gleich sein => es müsste ein flag geben um das zu markieren

# eventually wait for user input
if ($waitForUserInput)
{
	Write-Host -NoNewLine 'Press any key to continue...'
	$null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown')
}

# -------------------------
# Classes
# -------------------------

class Project 
{
	# Parameters for constructor
	[bool]$library
	[string]$name
	[string]$resourceFolder
	# Calculated parameters
	[System.Collections.ArrayList]$folders
	
	Project([bool]$library, [string]$name, [string]$resourceFolder)
	{
		$this.library = $library
		$this.name = $name
		$this.resourceFolder = $resourceFolder
	}
	
	[string] prettyFolderName($folder)
	{
		return "$($this.name) - $($folder.language) ($($folder.name))"
	}
	
	loadLanguages($stringFiles, $defaultLanguage)
	{		
		# 1) get all values* folders + filter out folders that do not contain any valid string file
		$this.folders = Get-ChildItem -Path $this.resourceFolder -Directory | Where-Object {$_.name -like "values*"} | Where-Object { ContainsAnyFile $_.FullName $stringFiles } | ForEach { [LanguageFolder]::New($_.Name, "values", "values-", $defaultLanguage) }
		
		$this.folders | ForEach { DEBUG("[INFO] $($this.prettyFolderName($_))") }
	}
	
	copyFiles($onlyIfNotExisting, $stringFiles, $directionProjectToGithub, [ref]$copiedToProject, [ref]$copiedToGithub)
	{
		foreach ($folder in $this.folders)
		{
			foreach ($file in $stringFiles)
			{
				$githubPath = "$($global:root)\$($this.name)\$($folder.name)\$file"
				$projectPath = "$($this.resourceFolder)\$($folder.name)\$file"
				
				$projectExists = [System.IO.File]::Exists($projectPath)
				$githubExists = [System.IO.File]::Exists($githubPath)
			
				$fromPath = if ($directionProjectToGithub) { $projectPath } else { $githubPath }
				$toPath = if ($directionProjectToGithub) { $githubPath } else { $projectPath }
				
				$fromExists = if ($directionProjectToGithub) { $projectExists } else { $githubExists }
				$toExists = if ($directionProjectToGithub) { $githubExists } else { $projectExists }
				
				$info = if ($directionProjectToGithub) { "Copy PROJECT => app-resources" } else { "Copy app-resources => PROJECT" }
				$fromFileName = if ($directionProjectToGithub) { "PROJECT file" } else { "app-resources file" }
				$toFileName = if ($directionProjectToGithub) { "app-resources file" } else { "PROJECT file" }
			
				if ($fromExists)
				{
					#DEBUG("[$info] $($this.name) - $fromFileName found: $file [$($folder.language)]")			
					if ((-not $onlyIfNotExisting) -or (-not $toExists)) 
					{
						DEBUG("[COPY] $($this.name): $toFileName $(if ($toExists) {'REPLACED'} else {'CREATED'}) - $file => $($folder.name) [$($folder.language)]")
						CopyFile $fromPath $toPath
						
						if ($directionProjectToGithub) { $copiedToGithub.value++ } else { $copiedToProject.value++ }
					}
				}
			}
		}
	}
	
	syncProject($stringFiles, $sourceLanguages, $modeOneWaySync, [ref]$copiedToProject, [ref]$copiedToGithub)
	{
		foreach ($folder in $this.folders)
		{
			foreach ($file in $stringFiles)
			{
				$githubPath = "$($global:root)\$($this.name)\$($folder.name)\$file"
				$projectPath = "$($this.resourceFolder)\$($folder.name)\$file"
				
				# destinct between modes
				if ($modeOneWaySync)
				{
					# we ALWAYS copy source languages from projects to github
					# and we ALWAYS copy non source languages from github to projects
					
					$isSourceLanguage = $sourceLanguages -contains $folder.language
					
					$fromPath = if ($isSourceLanguage) { $projectPath } else { $githubPath }
					$toPath = if ($isSourceLanguage) { $githubPath } else { $projectPath }
					$toFileName = if ($isSourceLanguage) { "app-resources file" } else { "PROJECT file" }
					
					$fromExists = [System.IO.File]::Exists($fromPath)
					
					if ($fromExists)
					{
						$toExists = [System.IO.File]::Exists($toPath)
						$fromIsNewer = (-not $toExists) -or (IsFileNewer $fromPath $toPath)
						
						if ($fromIsNewer) 
						{
							DEBUG("[SYNC] $($this.name): $toFileName $(if ($toExists) {'REPLACED'} else {'CREATED'}) - $file => $($folder.name) [$($folder.language)]")
							CopyFile $fromPath $toPath
							
							if ($isSourceLanguage) { $copiedToGithub.value++ } else { $copiedToProject.value++ }
						}
					}
				}
				else
				{
					# we check last change date and always copy newer files over older files
					Write-Host "CURRENTLY ONLY modeOneWaySync == true is supported!"
				}				
			}
		}
	}
}

class LanguageFolder
{
	[string]$name
	[string]$language
	[bool]$default
	
	LanguageFolder([string]$name, [string]$defaultFolder, [string]$partOfNameToRemove, [string]$defaultLanguage)
	{
		$this.name = $name
		$this.default = $name -eq $defaultFolder
		if ($this.default) 
		{
			$this.language = $defaultLanguage
		}
		else
		{
			$this.language = $name.Replace($partOfNameToRemove, "")
		}
	}
}