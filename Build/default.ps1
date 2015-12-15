properties {
	$buildConfiguration = "Release"
	$buildPlatform = "Any CPU"

	$testMessage = 'Execute Test!'
	$compileMessage = 'Executed Compile!'
	$cleanMessage = 'Executed Clean!'
	$solutionDirectory = (Get-Item $solutionFile).DirectoryName
	$outputDirectory = "$solutionDirectory\.build"
	$tempDirectory = "$outputDirectory\temp"

	$publishedNUnitTestsDirectory = "$tempDirectory\_PublisherNUnitTests"
	$testResultsDirectory = "$outputDirectory\TestResults"
	$NUnitTestResultsDirectory = "$testResultsDirectory\NUnit"
	$NUnitExe = ((Get-ChildItem("..\packages\NUnit.Runners*")) | Select-Object $_.FullName | Sort-Object $_ | 
			Select -Last 1).FullName + "\tools\nunit-console-x86.exe"
	$openCoverExe = ((Get-ChildItem("..\packages\OpenCover*")) | Select-Object $_.FullName | Sort-Object $_ |
			Select -Last 1).FullName + "\tools\OpenCover.Console.exe"
	$reportGeneratorExe = ((Get-ChildItem("..\packages\ReportGenerator*")) | Select-Object $_.FullName | Sort-Object $_ |
			Select -Last 1).FullName + "\tools\ReportGenerator.exe"

	$testCoverageDirectory = "$outputDirectory\TestCoverage"
	$testCoverageReportPath = "$testCoverageDirectory\OpenCover.xml"
	$testCoverageFilter = "+[*]* -[*.Tests]*"  #+/-[MyAssembly]MyNamespace
	$testCoverageExcludeByAttribute = "System.Diagnostics.CodeAnalysis.ExcludeFromCodeCoverage"
	$testCoverageExcludeByFile = "*\*Designer.cs;*\*.g.cs;*\*.g.i.cs"
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
	Assert (Test-Path $openCoverExe) "OpenCover Console could not be found"
	Assert (Test-Path $reportGeneratorExe) "ReportGenerator could not be found"

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

	# Create the test results directory if needed
	if(!(Test-Path $NUnitTestResultsDirectory))
	{
		Write-Host "Creating tests results directory at $NUnitTestResultsDirectory"
		mkdir $NUnitTestResultsDirectory | Out-Null
	}

	# Create the test coverage directory if needed
	if(!(Test-Path $testCoverageDirectory))
	{
		Write-Host "Creating test coverage directory at $testCoverageDirectory"
		mkdir $testCoverageDirectory | Out-Null
	}

	# Get the list of dlls
	$testAssemblies = $projects | ForEach-Object {"`"`"" + $_.FullName + "\" + $_.Name + ".dll`"`"" }
	$testAssembliesParameter = [string]::Join(" ", $testAssemblies)

	$targetArgs = "$testAssembliesParameter /xml:`"`"$NUnitTestResultsDirectory\NUnit.xml`"`" /nologo /noshadow"

	# Run OpenCover, which in turn will run NUnit
	Exec {
		&$openCoverExe -target:$NunitExe `
					   -targetargs:$targetArgs `
					   -output:$testCoverageReportPath `
					   -register:user `
					   -filter:$testCoverageFilter `
					   -excludebyattribute:$testCoverageExcludeByAttribute `
					   -excludebyfile:$testCoverageExludeByFile `
					   -skipautoprops `
					   -mergebyhash `
					   -mergeoutput `
					   -hideskipped:All `
					   -returntargetcode }
}

task Test -depends Compile, TestNUnit -description "Run the tests" {
	
	if(Test-Path $testCoverageReportPath)
	{
		# Generate HTML test coverage report
		Write-Host "`r`n Generating HTML test coverage report"
		Exec { &$reportGeneratorExe $testCoverageReportPath $testCoverageDirectory }

		Write-Host "Parsing OpenCover results"

		# Load the coverage report as XML
		$coverage = [xml](Get-Content -Path $testCoverageReportPath)
		$coverageSummary = $coverage.CoverageSession.Summary

		# Write class coverage
		Write-Host "##teamcity[buildStatisticValue key='CodeCoverageAbsCCovered' value='$($coverageSummary.visitedClasses)']"
		Write-Host "##teamcity[buildStatisticValue key='CodeCoverageAbsCTotal' value='$($coverageSummary.numClasses)']"
		Write-Host "##teamcity[buildStatisticValue key='CodeCoverageC' value='{0:N2}']" f (($coverageSummary.visitedClasses / $coverageSummary.numClasses)*100)

		# Report method coverage
		Write-Host "##teamcity[buildStatisticValue key='CodeCoverageAbsMCovered' value='$($coverageSummary.visitedMethods)']"
		Write-Host "##teamcity[buildStatisticValue key='CodeCoverageAbsMTotal' value='$($coverageSummary.numMethods)']"
		Write-Host "##teamcity[buildStatisticValue key='CodeCoverageM' value='{0:N2}']" f (($coverageSummary.visitedMethods/$coverageSummary.numMethods)*100)

		# Report branch coverage
		Write-Host "##teamcity[buildStatisticValue key='CodeCoverageAbsBCovered' value='$($coverageSummary.visitedBranchPoints)']"
		Write-Host "##teamcity[buildStatisticValue key='CodeCoverageAbsBTotal' value='$($coverageSummary.numBranchPoints)']"
		Write-Host "##teamcity[buildStatisticValue key='CodeCoverageB' value='{0:N2}']" f (($coverageSummary.visitedBranchPoints/$coverageSummary.numBranchPoints)*100)

		# Report statement point coverage
		Write-Host "##teamcity[buildStatisticValue key='CodeCoverageAbsSCovered' value='$($coverageSummary.visitedSequencePoints)']"
		Write-Host "##teamcity[buildStatisticValue key='CodeCoverageAbsSTotal' value='$($coverageSummary.numSequencePoints)']"
		Write-Host "##teamcity[buildStatisticValue key='CodeCoverageS' value='$($coverageSummary.sequenceCoverage)']"

	}
	else
	{
		Write-Host "No coverage file found at: $testCoveragePath"
	}
}
