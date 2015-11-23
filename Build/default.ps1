properties {
    $testMessage = 'Execute Test!'
    $compileMessage = 'Executed Compile!'
    $cleanMessage = 'Executed Clean!'
	$solutionDirectory = (Get-Item $solutionFile).DirectoryName
	$outputDirectory = "$solutionDirectory\.build"
	$tempDirectory = "$outputDirectory\temp"

	$publishedNUnitTestsDirectory = "$tempDirectory\_PublisherNUnitTests"
	$testResultsDirectory = "$outputDirectory\TestResults"
	$NUnitTestResultsDirectory = "$testResultsDirectory\NUnit"
	$NUnitExe = ((Get-ChildItem("..\packages\NUnit.Runners*")) | 
			Select-Object $_.FullName | 
			Sort-Object $_ | 
			Select -Last 1).FullName + "\tools\nunit-console-x86.exe"

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

	# Check that all tools are available
	Write-Host "Checking that all required tools are available"

	Assert (Test-Path $NUnitExe) "NUnit Console could not be found"

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

task Test -depends Compile, TestNUnit -description "Run the tests" {
	Write-Host $testMessage
}

task TestNUnit -depends Compile `
			   -description "Run NUnit Tests" {
	$projects = Get-ChildItem $publishedNUnitTestsDirectory

	if($projects.Count -eq 1)
	{
		Write-Host "1 NUnit project has been found:"
	}
	else
	{
		Write-Host $projects.Count " NUnit projects have been found:"
	}

	Write-Host ($projects | Select $_.Name)

	# Create the tests results directory if needed
	if(!(Test-Path $NUnitTestResultsDirectory))
	{
		Write-Host "Creating tests results directory at $NUnitTestResultsDirectory"
		mkdir $NUnitTestResultsDirectory | Out-Null
	}

	# Get the list of dlls
	$testAssemblies = $projects | ForEach-Object { $_.FullName + "\" + $_.Name + ".dll" }
	$testAssembliesParameter = [string]::Join(" ", $testAssemblies)

	Exec { 
		&$NunitExe $testAssembliesParameter /xml:$NUnitTestResultsDirectory\NUnit.xml /nologo /noshadow }
}