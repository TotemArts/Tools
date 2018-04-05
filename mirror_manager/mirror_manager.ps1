Param (
	[parameter(Mandatory=$true)]
	[ValidateSet('add','remove','list')]
	[string]$Action,

	[string]$Url,
	[string]$Name,
	[string]$Out="version/",
	[string]$SourceVersion="https://static.renegade-x.com/launcher_data/version/release.json",
	[switch]$DryRun
)

function ListMirrors($Json) {
	return ($Json.game.mirrors | ConvertTo-Json)
}

function ValidateMirror([string] $Url) {
	Invoke-WebRequest -URI ($Url + "10kb_file") | Out-Null
	echo "Mirror seems valid"
}

function ConfirmMirror($Mirror) {
	# Display mirror
	Write-Host ($Mirror | ConvertTo-Json)

	# Get confirmation from user
	$input = (Read-Host "Is this the correct mirror data? (yes/no)")

	# Translate input to boolean value
	if ($input -eq "y") {
		return $true
	}
	if ($input -eq "yes") {
		return $true
	}
	if ($input -eq "true") {
		return $true
	}
	if ($input -eq "n") {
		return $false
	}
	if ($input -eq "no") {
		return $false
	}
	if ($input -eq "false") {
		return $false
	}

	# Invalid input; reprompt user
	Write-Host ('Invalid Option "' + $input + '"')
	return (ConfirmMirror $Mirror)
}

function GenerateJson($Json, [string]$Url) {
	# Get Filename from URL
	$Filename = $Url.Split("/")[-1]

	# Fetch JSON at Url and update launcher information
	$TargetJson = ((Invoke-WebRequest -URI $Url).Content | ConvertFrom-Json)
	$TargetJson.game.mirrors = $Json.game.mirrors

	# Write JSON out to disk
	$TargetJson | ConvertTo-Json -Depth 10 | Set-Content ($Out + $Filename)
}

function RemoveMirrorFromJson($Json, [string]$Url) {
	[bool]$Success=$false

	# Search for the mirror based on URL
	ForEach ($Mirror in $Json.game.mirrors) {
		if ($Mirror.url -eq $Url) {
			# Confirm mirror with user
			if (ConfirmMirror $Mirror) {
				# Remove the mirror
				$Json.game.mirrors = ($Json.game.mirrors -ne $Mirror)
				return $true
			}

			# User said no
			return $false
		}
	}

	return $false
}

function Publish() {
	if (!$DryRun) {
		bash --login publish_version.sh
	}
}

# Cleanup from previous runs
Remove-Item -Recurse -Force $Out *>$null

# Get current release JSON
$Json = (Invoke-WebRequest -URI $SourceVersion).Content | ConvertFrom-Json

if ($Action -eq "list") {
	# List mirrors to console
	ListMirrors $Json
}
elseif ($Action -eq "add") {
	# Get any missing parameters
	if (!$Url) {
		$Url = (Read-Host "Server URL")
	}
	if (!$Name) {
		$Name = (Read-Host "Server Name")
	}

	# Validate Mirror
	ValidateMirror $Url

	# Add mirror to Json
	$Mirror = New-Object PsObject -Property @{ url=$Url ; name=$Name }

	# Confirm mirror data with user
	if (ConfirmMirror $Mirror) {
		# Add mirror to Json
		$Json.game.mirrors += $Mirror

		# Update standard version files
		New-Item -ItemType Directory -Path $Out
		GenerateJSON $Json "https://static.renegade-x.com/launcher_data/version/release.json"
		GenerateJSON $Json "https://static.renegade-x.com/launcher_data/version/beta.json"
		GenerateJSON $Json "https://static.renegade-x.com/launcher_data/version/server.json"

		# Update legacy version file
		# Fetch JSON at Url and update launcher information
		$TargetJson = ((Invoke-WebRequest -URI "https://static.renegade-x.com/launcher_data/version/legacy.json").Content | ConvertFrom-Json)
		$TargetJson.game.mirrors = $Json.game.mirrors
		$TargetJson.game.patch_urls += $Url

		# Write JSON out to disk
		$TargetJson | ConvertTo-Json -Depth 10 | Set-Content ($Out + "legacy.json")

		# We're all done; publish our results
		Publish
	}
}
elseif ($Action -eq "remove") {
	# Get any missing parameters
	if (!$Url) {
		$Url = (Read-Host "Server URL")
	}

	# Remove mirror from Json
	if (RemoveMirrorFromJson $Json $Url) {
		# Update standard version files
		New-Item -ItemType Directory -Path $Out
		GenerateJSON $Json "https://static.renegade-x.com/launcher_data/version/release.json"
		GenerateJSON $Json "https://static.renegade-x.com/launcher_data/version/beta.json"
		GenerateJSON $Json "https://static.renegade-x.com/launcher_data/version/server.json"

		# Update legacy version file
		# Fetch JSON at Url and update launcher information
		$TargetJson = ((Invoke-WebRequest -URI "https://static.renegade-x.com/launcher_data/version/legacy.json").Content | ConvertFrom-Json)
		$TargetJson.game.mirrors = $Json.game.mirrors
		$TargetJson.game.patch_urls = ($TargetJson.game.patch_urls -ne $Url)

		# Write JSON out to disk
		$TargetJson | ConvertTo-Json -Depth 10 | Set-Content ($Out + "legacy.json")

		# We're all done; publish our results
		Publish
	}
	else {
		echo ('Failed to remove mirror: "' + $Url + '"')
	}
}