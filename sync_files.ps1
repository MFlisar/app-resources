# -------------------------
# Setup
# -------------------------

# 1) define all projects and libraries
$projects = New-Object System.Collections.ArrayList
#$projects += [Project]::New($false, "Everywhere Launcher", 	"M:\dev\apps\EverywhereLauncher\app-resources\src\main\res", 	"261063", "everywherelauncher_")
#$projects += [Project]::New($false, "CoSy\main", 			"M:\dev\apps\CoSy\app\src\main\res", 							"261063", "cosy_")
#$projects += [Project]::New($false, "CoSy\facebook", 		"M:\dev\apps\CoSy\app\src\facebook\res", 						"261063", "cosy_fb_")
#$projects += [Project]::New($false, "CoSy\whatsapp", 		"M:\dev\apps\CoSy\app\src\whatsapp\res", 						"261063", "cosy_wa_")
$projects += [Project]::New($true, "Backup Manager", 		"M:\dev\libraries\backupManager\src\main\res", 					"261063", "backupmanager_")

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

$global:scriptRoot = Get-Location
$global:root = "$($global:scriptRoot)\projects"
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

# 3) ask user what he wants to do
Write-Host "`n-------------------------"
Write-Host "- What do you want to do?"
Write-Host "-------------------------"
Write-Host "- [s] sync                   - upload default languages + download non default languages"
Write-Host "- [d] download               - only download all non default languages"
Write-Host "- [l] local sync             - only run local syncs"
Write-Host "- [U] UPLOAD ALL (DANGEROUS) - upload all (INCL. non default languages)"
Write-Host "-------------------------`n"

$userInput = Read-Host -Prompt 'Selection: '

$uploadSourceLanguages = $false
$uploadNonSourceLanguages = $false
$downloadNonSourceLanguages = $false

if ($userInput -ieq "s")
{
	# sync
	$uploadSourceLanguages = $true
	$downloadNonSourceLanguages = $true
}
elseif ($userInput -ieq "d")
{
	# download only
	$downloadNonSourceLanguages = $true
}
elseif ($userInput -ieq "l")
{
	# local sync only
}
elseif ($userInput -eq "U")
{
	# upload all
	$uploadNonSourceLanguages = $true
}
else
{
	Write-Host "Script cancelled because of invalid input ($userInput)"
	return
}

# 4) copy all NOT YET existing files from each project to github and vice versa
Write-Host "- 1) Preparing projects"
$copiedToProject = 0
$copiedToGithub = 0
$projects | ForEach { $_.copyFiles($true, $stringFiles, $true, [ref]$copiedToProject, [ref]$copiedToGithub) }
$projects | ForEach { $_.copyFiles($true, $stringFiles, $false, [ref]$copiedToProject, [ref]$copiedToGithub) }
PrintCopyInfo $copiedToGithub $copiedToProject
Write-Host "- 2) Found following $($projects.count) project(s):"
$projects | ForEach { Write-Host "-    $($_.name) - folders: $($_.folders.count)" }

# 5) sync all files between project and github repository
Write-Host "- 3) Synced files"
$copiedToProject = 0
$copiedToGithub = 0
$projects | ForEach { $_.syncProject($stringFiles, $sourceLanguages, $modeOneWaySync, [ref]$copiedToProject, [ref]$copiedToGithub) }
PrintCopyInfo $copiedToGithub $copiedToProject

# 6) upload/download from onesky
if ($modeOneWaySync)
{
	if ($uploadSourceLanguages -or $uploadNonSourceLanguages) { DEBUG("") }
	
	# 6.1) upload all source languages
	if ($uploadSourceLanguages) { $projects | ForEach { $_.upload($stringFiles, $sourceLanguages, $modeOneWaySync, $false) } }
	
	# 6.2) upload all non source languages
	if ($uploadNonSourceLanguages) { $projects | ForEach { $_.upload($stringFiles, $sourceLanguages, $modeOneWaySync, $true) } }
	
	if ($uploadSourceLanguages -or $uploadNonSourceLanguages) { DEBUG("") }
	
	# 6.3) download all other languages - we must download all, we don't know if something changes
	if ($downloadNonSourceLanguages) { $projects | ForEach { $_.download($stringFiles, $sourceLanguages, $modeOneWaySync) } }
	
	if ($uploadSourceLanguages -or $uploadNonSourceLanguages) { DEBUG("") }
	
	# 6.4) sync from github to projects - only downloaded files
	if ($downloadNonSourceLanguages)
	{
		Write-Host "- 4) Synced files - AFTER up-/download"
		$copiedToProject = 0
		$copiedToGithub = 0
		$projects | ForEach { $_.syncProject($stringFiles, $sourceLanguages, $modeOneWaySync, [ref]$copiedToProject, [ref]$copiedToGithub) }
		PrintCopyInfo $copiedToGithub $copiedToProject
	}
}
else
{
	# we would need to check which files are newer + handle changes on both sides...
	Write-Host "CURRENTLY ONLY modeOneWaySync == true is supported!"
}

Write-Host "-------------`n"

# 7) eventually wait for user input
if ($waitForUserInput)
{
	Write-Host -NoNewLine 'Press any key to continue...'
	$null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown')
	Write-Host "`n"
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
	[string]$onyskyProjectId
	[string]$oneskyFilePrefix
	# Calculated parameters
	[System.Collections.ArrayList]$folders
	[System.Collections.ArrayList]$changedFiles
	
	Project([bool]$library, [string]$name, [string]$resourceFolder, [string]$onyskyProjectId, [string]$oneskyFilePrefix)
	{
		$this.library = $library
		$this.name = $name
		$this.resourceFolder = $resourceFolder
		$this.onyskyProjectId = $onyskyProjectId
		$this.oneskyFilePrefix = $oneskyFilePrefix
		$this.changedFiles = New-Object System.Collections.ArrayList
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
				$paths = [Paths]::New($this, $folder, $file)

				$fromPath = if ($directionProjectToGithub) { $paths.projectPath } else { $paths.githubPath }
				$toPath = if ($directionProjectToGithub) { $paths.githubPath } else { $paths.projectPath }
				
				$fromExists = if ($directionProjectToGithub) { $paths.projectExists } else { $paths.githubExists }
				$toExists = if ($directionProjectToGithub) { $paths.githubExists } else { $paths.projectExists }
				
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
						
						$this.changedFiles += [ChangedFile]::New($folder, $file, $directionProjectToGithub)
					}
				}
			}
		}
	}
	
	syncProject($stringFiles, $sourceLanguages, $modeOneWaySync, [ref]$copiedToProject, [ref]$copiedToGithub)
	{
		if (-not $modeOneWaySync)
		{
			Write-Host "CURRENTLY ONLY modeOneWaySync == true is supported!"
			return
		}
				
		foreach ($folder in $this.folders)
		{
			$isSourceLanguage = $sourceLanguages -contains $folder.language
			
			foreach ($file in $stringFiles)
			{
				$paths = [Paths]::New($this, $folder, $file)
				
				# we ALWAYS copy source languages from projects to github
				# and we ALWAYS copy non source languages from github to projects

				$fromPath = if ($isSourceLanguage) { $paths.projectPath } else { $paths.githubPath }
				$toPath = if ($isSourceLanguage) { $paths.githubPath } else { $paths.projectPath }
				$toFileName = if ($isSourceLanguage) { "app-resources file" } else { "PROJECT file" }
				
				$fromExists = if ($isSourceLanguage) { $paths.projectExists } else { $paths.githubExists }
				
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
		}
	}
	
	upload($stringFiles, $sourceLanguages, $modeOneWaySync, $onlyNonSourceLanguages)
	{
		if (-not $modeOneWaySync)
		{
			Write-Host "CURRENTLY ONLY modeOneWaySync == true is supported!"
			return
		}
		
		# 1) move to onesky directory
		Set-Location -Path ".\onesky"
	
		# 2) upload all sourceLanguages or non sourceLanguages - no checks done, we actually don't know if current files have already been uploaded
		foreach ($folder in $this.folders)
		{
			$isSourceLanguage = $sourceLanguages -contains $folder.language			
			if ($isSourceLanguage -or $onlyNonSourceLanguages)
			{
				foreach ($file in $stringFiles)
				{
					$paths = [Paths]::New($this, $folder, $file)
					$exists = $paths.projectExists
					
					if ($exists)
					{
						DEBUG("[UPLOAD ONESKY] $($this.name): $file | $($folder.name) [$($folder.language)]")
						
						$action = "upload"
						$projectId = $this.onyskyProjectId
						$filePath = $paths.githubPath
						$oneskyFileName = "$($this.oneskyFilePrefix)$file"
						$language = $folder.language
						npm run onesky_script -- $action $projectId $filePath $oneskyFileName $language | Select-Object -Skip 4 | Write-Host
					}
				}
			}
		}
		
		# 2) upload all sourceLanguages with changes
		#foreach ($changed in $this.changedFiles)
		#{
		#	if ($changed.directionProjectToGithub)
		#	{
		#		$isSourceLanguage = $sourceLanguages -contains $changed.folder.language
		#		if ($isSourceLanguage -or $onlyNonSourceLanguages)
		#		{
		#			$paths = [Paths]::New($this, $changed.folder, $changed.name)
		#			
		#			DEBUG("[UPLOAD ONESKY] $($this.name): $($changed.name) | $($changed.folder.name) [$($changed.folder.language)]")
		#			
		#			$action = "upload"
		#			$label = $this.prettyFolderName($changed.folder)
		#			$projectId = $this.onyskyProjectId
		#			$filePath = $paths.githubPath
		#			$oneskyFileName = "$($this.oneskyFilePrefix)$($changed.name)"
		#			$language = $changed.folder.language
		#			Write-Host (npm run onesky_script -- $action $label $projectId $filePath $oneskyFileName $language) -Separator `n
		#		}
		#	}
		#}
		
		# 3) move back out of onesky directory
		Set-Location -Path ".."
	}
	
	download($stringFiles, $sourceLanguages, $modeOneWaySync)
	{
		if (-not $modeOneWaySync)
		{
			Write-Host "CURRENTLY ONLY modeOneWaySync == true is supported!"
			return
		}
		
		# 1) move to onesky directory
		Set-Location -Path ".\onesky"
	
		# 2) download all non sourceLanguages - we don't know if there are changes, so must download all of them
		foreach ($folder in $this.folders)
		{
			$isSourceLanguage = $sourceLanguages -contains $folder.language			
			if (-not $isSourceLanguage)
			{
				foreach ($file in $stringFiles)
				{
					$paths = [Paths]::New($this, $folder, $file)
					$exists = $paths.projectExists
					
					if ($exists)
					{
						DEBUG("[DOWNLOAD ONESKY] $($this.name): $file | $($folder.name) [$($folder.language)]")
						
						$action = "download"
						$projectId = $this.onyskyProjectId
						$filePath = $paths.githubPath
						$oneskyFileName = "$($this.oneskyFilePrefix)$file"
						$language = $folder.language
						npm run onesky_script -- $action $projectId $filePath $oneskyFileName $language | Select-Object -Skip 4 | Write-Host
					}
				}
			}
		}
		
		# 3) move back out of onesky directory
		Set-Location -Path ".."
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

class Paths
{
	[string]$githubPath
	[string]$projectPath
	[bool]$githubExists
	[bool]$projectExists
	
	Paths($project, $folder, $file)
	{
		$this.githubPath = "$($global:root)\$($project.name)\$($folder.name)\$file"
		$this.projectPath = "$($project.resourceFolder)\$($folder.name)\$file"
		
		$this.githubExists = [System.IO.File]::Exists($this.githubPath)
		$this.projectExists = [System.IO.File]::Exists($this.projectPath)
		
	}
}

class ChangedFile
{
	[LanguageFolder]$folder
	[string]$name
	[bool]$directionProjectToGithub
	
	ChangedFile($folder, $name, $directionProjectToGithub)
	{
		$this.folder = $folder
		$this.name = $name	
		$this.directionProjectToGithub = $directionProjectToGithub			
	}
}