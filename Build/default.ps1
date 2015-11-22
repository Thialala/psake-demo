properties {
    $testMessage = 'Execute Test!'
    $compileMessage = 'Executed Compile!'
    $cleanMessage = 'Executed Clean!'
	$solutionDirectory = (Get-Item $solutionFile).DirectoryName
	$outputDirectory = "$solutionDirectory\.build"
	$tempDirectory = "$outputDirectory\temp"
	$buildConfiguration = "Release"
	$buildPlatform = "Any CPU"
}

FormatTaskName "`r`n`r`n---------- Executing {0} Task --------"

task default -depends Test

task Init -description "Initialises the build by removing previous artifacts and creating output directory" `
		  -requiredVariables outputDirectory, tempDirectory {
	
    Assert ("Debug", "Release" -contains $buildConfiguration) `
		   -failureMessage "Invalid build configuration '$buildConfiguration'. Valid values are 'Debug' or 'Release'"

	Assert ("x86", "x64", "Any CPU" -contains $buildPlatform) `
		   "Invalid build platform '$buildPlatform'. Valid values are 'x86', 'x64' or 'Any CPU'"

	# Remove output directory
	if(Test-Path $outputDirectory)
	{
		Write-Host "Removing $outputDirectory"
		Remove-Item $outputDirectory -Force -Recurse
    }

	Write-Host "Creating output directory located at ..\.build"
	New-Item $outputDirectory -ItemType Directory | Out-Null

	Write-Host "Creating temp directory located at ..\.build\temp"
	New-Item $tempDirectory -ItemType Directory | Out-Null
}

task Clean -description "Remove temporary files" {
    Write-Host $cleanMessage
}

task Compile -depends Init `
			 -description "Compile the code" `
			 -requiredVariables solutionFile, buildConfiguration, buildPlatform, tempDirectory {
	Write-Host "Building solution $solutionFile"
	Exec {  
		msbuild $solutionFile "/p:Configuration=$buildConfiguration;Platform=$buildPlatform;OutDir=$tempDirectory"
	}
}

task Test -depends Compile, Clean -description "Run the tests" {
	Write-Host $testMessage
}