# Find solution file.
$solutionFile = Get-ChildItem -Path . -Filter *.sln -Recurse | Select-Object -First 1

if ($null -eq $solutionFile)
{
    # Solution file not found. Looking for project files.
    Write-Output 'Solution file not found. Looking for project files.'
    $projectFiles = Get-ChildItem -Path . -Recurse | Where-Object { $PSItem.Extension -eq '.csproj' -or $PSItem.Extension -eq '.fsproj' }
}
else
{
    # Solution file found. Extracting project files.
    Write-Output "Solution file found: $($solutionFile.FullName). Extracting project files."
    $projectPaths = dotnet sln $($solutionFile.FullName) list | Select-Object -Skip 2
    $projectFiles = $projectPaths | ForEach-Object { Get-Item -Path $PSItem }
}

foreach ($projectFile in $projectFiles)
{
    # Below we first prepare the project file by adding the NuGetBuild=true property to the top of it. This is needed
    # for dotnet add package which could otherwise fail due to conditions in the project file.

    # Load the project file as XML.
    $projectXml = [xml](Get-Content $projectFile)

    # Define the xmlns to access the elements in the csproj.
    $ns = New-Object Xml.XmlNamespaceManager $projectXml.NameTable
    $ns.AddNamespace('ns', $projectXml.DocumentElement.NamespaceURI)

    # Create a new NuGetBuild property in a new PropertyGroup.
    $propertyGroup = $projectXml.CreateElement('PropertyGroup', $projectXml.DocumentElement.NamespaceURI)
    $nuGetBuildNode = $projectXml.CreateElement('NuGetBuild', $projectXml.DocumentElement.NamespaceURI)
    $nuGetBuildNode.InnerText = 'true'
    $propertyGroup.AppendChild($nuGetBuildNode)

    # Add the new PropertyGroup to the project as the first node, to make sure that it's fully applied.
    $projectXml.Project.InsertBefore($propertyGroup, $projectXml.Project.FirstChild)

    # Save the changes back to the .csproj file.
    $projectXml.Save($projectFile)

    # --no-restore would also skip compatibility checks. So, we don't use it, even though running restore in a separate
    # step with a configured output verbosity, what's only possible with the dotnet restore command, would be better.
    dotnet add $projectFile.FullName package 'Microsoft.SourceLink.GitHub' --source 'https://api.nuget.org/v3/index.json'
}

Write-Output 'SourceLink package added to all projects.'
