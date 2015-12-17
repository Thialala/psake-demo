param(
	[Int32]$buildNumber=0,
	[String]$branchName="localBuild",
	[String]$gitCommitHash="unknownHash",
	[Switch]$isMainBranch=$False
)

cls

# Remove psake
Remove-Module [p]sake

# find psake's path
$psakeModule = (Get-ChildItem(".\packages\psake*\tools\psake.ps1")) | 
	Select-Object $_.FullName | 
	Sort-Object $_ | 
	Select -Last 1

Import-Module $psakeModule

Invoke-psake -buildFile .\Build\default.ps1 `
			 -taskList Package `
			 -framework 4.5.2 `
			 -properties @{
							"buildConfiguration"="Release"
							"buildPlatform"="Any CPU"
						  } `
			 -parameters @{
				 "solutionFile"="..\psake.sln"
				 "buildNumber" = $buildNumber
				 "branchName" = $branchName
				 "gitCommitHash" = $gitCommitHash
				 "isMainBranch" = $isMainBranch
			 }

Write-Host "Build exit code:" $LASTEXITCODE

# Progating the exit code
exit $LASTEXITCODE



