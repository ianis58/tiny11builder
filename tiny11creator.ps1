#Defining preferences variables
clear
Write-Output "Loading configuration from config.json..."
$config = (Get-Content "config.json" -Raw) | ConvertFrom-Json
$wantedImageName = $config.WantedWindowsEdition
$unwantedProvisionnedPackages = $config.ProvisionnedPackagesToRemove
$unwantedWindowsPackages = $config.WindowsPackagesToRemove
$pathsToDelete = $config.PathsToDelete
$windowsIsoDownloaderReleaseUrl = $config.WindowsIsoDownloaderReleaseUrl

$defaultIsoName = "windows11.iso"
$defaultTinyIsoName = "tiny11.iso"

#########################################################
    #             Prepare WORKDIR PATH!             #    
#########################################################
Write-Output "..............................................................................................`n"
Write-Output "Would you like to change the work directory? DEFAULT is 'C:\tiny11\'." 
Write-Output "[This will decide downloaded windows image path as well ex: c:\$defaultIsoName]`n" 
Write-Output "[1]. Use the default path."
Write-Output "[2]. Change default path."

$workDirOption = (Read-Host -Prompt "Please select option") -replace " ",""
while ( -not($workDirOption -ge 1 -and $workDirOption -le 2) ) {
	$workDirOption = Read-Host -Prompt 'Please choose valid option'
}
if ($workDirOption  -eq "2") {
	$rootWorkdir = (Read-Host -Prompt "`nPlease insert your a valid directory path where 'tiny11' folder will be created. Spaces Aren't allowed! e.g [ c:\ ]`nYour Path").Trim('"')
	# Make sure input isn't empty. otherwise check if it's valid path.
	if ($rootWorkdir -eq "" -or $rootWorkdir -eq $null) {$correctDir = $false} else {
		if((Test-Path -Path $rootWorkdir -PathType Container) -and ($rootWorkdir -notlike "* *" )) {
			$correctDir=$true
		}
		elseif( $rootWorkdir.ToLower().EndsWith(".iso") -and (([System.IO.Path]::GetDirectoryName($rootWorkdir)) -notlike "* *" ) ) {
			# Check if file exists.
			if (Test-Path -Path $rootWorkdir -PathType Leaf){
				$correctDir=$true 
				$providedImage = $rootWorkdir
			}
		}
	}
	while (!$correctDir) {
		# Try to check the error then explain it in error_message.
		if ($rootWorkdir -like "* *" -and ([System.IO.Path]::GetDirectoryName($rootWorkdir))) {$error_message = "`nSpaces aren't Allowed!"} # If there is spaces.
		else {$error_message = "`nPlease insert the valid directory path will be assign`nYour Path"}

		$rootWorkdir = (Read-Host -Prompt "$error_message").Trim('"')
		# Test of valid inputs.
		if(($rootWorkdir) -and ($rootWorkdir -notlike "* *")) {
			# In-case user provide Folder, next step ask for images.
			if(Test-Path -Path $rootWorkdir -PathType Container) {
				$correctDir=$true 
				$rootWorkdir = Join-Path -Path $rootWorkdir -ChildPath "tiny11\"
			}
			# In-case user provided an ISO File We assume WORKDIR in the same folder.
			elseif ( $rootWorkdir.ToLower().EndsWith(".iso") -and (([System.IO.Path]::GetDirectoryName($rootWorkdir)) -notlike "* *") ) { 
				# Check if file exists.
				if (Test-Path -Path $rootWorkdir -PathType Leaf) {
					$correctDir=$true 
					$providedImage = $rootWorkdir
				}
			}
		}
	}

	$fileDirectory = [System.IO.Path]::GetDirectoryName($rootWorkdir)
	$rootWorkdir = Join-Path -Path $fileDirectory -ChildPath "tiny11\"
}
#########################################################
    #              Prepare Variables!              #    
#########################################################
$yes = (cmd /c "choice <nul 2>nul")[1]
#The $yes variable gets the "y" from "yes" (or corresponding letter in the language your computer is using).
#It is used to answer automatically to the "takeown" command, because the answer choices are localized which is not handy at all.

$rootWorkdir = if (-not($rootWorkdir)) {"c:\tiny11\"} else {$rootWorkdir}
$isoFolder = $rootWorkdir + "iso\"
$installImageFolder = $rootWorkdir + "installimage\"
$bootImageFolder = $rootWorkdir + "bootimage\"
$toolsFolder = $rootWorkdir + "tools\"

$isoPath =  Join-Path -path $rootWorkdir -ChildPath $defaultIsoName
$tinyPath = Join-Path -path $isoPath -ChildPath $defaultTinyIsoName

#########################################################
    #          Prepare Windows Image Path!          #    
#########################################################
clear
# If the image was provided in WORKDIR Path we Don't need to ask for ISO path.
if ($providedImage){
	Write-Output "Already provided ISO file: $providedImage" 
	
	$isoPath = $providedImage
	$tinyPath = Join-Path -Path $fileDirectory -ChildPath $defaultTinyIsoName
	$_local_image = $true
} else {
# Otherwise if Folder was provided we will need the ISO Path.
	Write-Output "`n..............................................................................................`n"
	Write-Output "WORKDIR Path: $rootWorkdir"
	Write-Output "`n..............................................................................................`n"
	Write-Output "Would you like to download the latest version of Windows 11 or provide your own ISO file" 
	Write-Output "[1]. Download"
	Write-Output "[2]. Provide ISO File" 

	# Prompt message to choose Iso Path.
	$_choose_image = (Read-Host -Prompt 'Choose option') -replace " ",""
	# Make sure the selected option is valid.
	while ( -not($_choose_image -ge 1 -and $_choose_image -le 2) ) {
		$_choose_image = Read-Host -Prompt 'Please choose valid option'
	}
	# Get the image path if user select to provide existed image. 
	if ($_choose_image -eq "2") {
		$isoPath =  (Read-Host -Prompt "Please insert the ISO path location Example: c:\windows11.iso`nISO Path").Trim('"')
		# Make sure the provided images is valid.
		if ($isoPath -eq "" -or $isoPath -eq $null) {$correctISO = $false} else {
			# Check if input isn't empty before check file valid.
			if ($isoPath) { if( (Test-Path -Path $isoPath -PathType Leaf) -and  ($isoPath.EndsWith(".iso")) ) {$correctISO = $true} }
		}
		while  ( !$correctISO ) {
			# Check if input isn't empty before check file valid.
			$isoPath =  (Read-Host -Prompt "This file doesn't exist or not valid please insert valid ISO File path`nISO Path").Trim('"')
			if ($isoPath) { if( (Test-Path -Path $isoPath -PathType Leaf) -and  ($isoPath.EndsWith(".iso")) ) {$correctISO = $true} }
		}
		$_local_image = $true
		$tinyPath = Join-Path -path (Split-Path $isoPath -Parent ).ToString() -ChildPath $defaultTinyIsoName
	}
}

#########################################################
    #              CallBack Messages                #    
#########################################################
function callBack-MSG-processStarts {
	Write-Output "`..............................................................................................`n"
	Write-Output "TEMPORARY WORKDIR: $rootWorkdir"
	Write-Output "ISO Windows: $isoPath"
	Write-Output "Tiny11 ISO Image: $tinyPath"
	Write-Output "ISO FOLDER: $isoFolder"
	Write-Output "Windows Edition: $wantedImageName"
	Write-Output "`n..............................................................................................`n"
}
function callBack-commonWindowsEdition {
	$global:common_win_edition = @(
		"Windows 11 Home", 
		"Windows 11 Home N", 
		"Windows 11 Home Single Language",
		"Windows 11 Education",
		"Windows 11 Education N",
		"Windows 11 Pro",
		"Windows 11 Pro N",
		"Windows 11 Pro Education",
		"Windows 11 Pro Education N",
		"Windows 11 Pro for Workstations",
		"Windows 11 Pro N for Workstations"
	)
	clear
	callBack-MSG-processStarts
	Write-Output "Note* If you chose an edition that isn't exists the Image, A Message will shows up with the availables editions.`n"
	$imageSelect = 1
	foreach ($img in $common_win_edition) {
		Write-Output "[$imageSelect]. $img"
		$imageSelect++
	}
	$selectedEditionName = $common_win_edition[$selected_value -1]
	return $selected_value
}

#########################################################
    #             Process Confirmation              #    
#########################################################
while ($_confirm_user -notlike "*y" -and $_confirm_user -notlike "*n") {
	clear
	callBack-MSG-processStarts
	Write-Output "`nPress [i] to change Windows Edition.`n"
	$_confirm_user = Read-Host "`nDo you want to start the process? [y] or [n]"
	if ($_confirm_user.ToLower() -eq "i") {
		callBack-commonWindowsEdition
		while( ($selected_value -gt [int]$common_win_edition.Count) -or ($selected_value -lt 1)) {
			$selected_value = [int](Read-Host -Prompt "`nSelect an image by entering its corresponding number`nYour choice")
		}
		$wantedImageName = $common_win_edition[$selected_value -1]
	}

	
}
# If not restart the tool.
if ($_confirm_user -like "n" ) {
	Write-Output "Exiting..."
	Return
}

# Clean the script interface before starts the process.
clear
callBack-MSG-processStarts
#########################################################
    #           Download Windows IF Chose           #    
#########################################################
if ($_choose_image -eq "1")  {
	# Create Needed Folders!
	New-Item -ItemType Directory -Force -Path $rootWorkdir | Out-Null
	New-Item -ItemType Directory -Force -Path ($toolsFolder + "WindowsIsoDownloader\") | Out-Null

	# Download WindowsImage Downloader tool.
	Write-Output "Downloading WindowsIsoDownloader release from GitHub..."
	Invoke-WebRequest -Uri $windowsIsoDownloaderReleaseUrl -OutFile WindowsIsoDownloader.zip

	# Extracting The Tool.
	Write-Output "Extracting WindowsIsoDownloader release..."
	Expand-Archive -Path WindowsIsoDownloader.zip -DestinationPath ($toolsFolder + "WindowsIsoDownloader\") -Force
	Remove-Item WindowsIsoDownloader.zip | Out-Null

	# Rewrtie download path if needed in the tool Config!
	$_json_config_path = Join-Path -path $toolsFolder -ChildPath "WindowsIsoDownloader\config.json"
	$json = get-content $_json_config_path  | ConvertFrom-Json
	$json.DownloadFolder = (Split-Path $rootWorkdir -Parent).ToString()
	ConvertTo-Json $json -Depth 10 | Out-File $_json_config_path -Force
	
	# Downloading the Windows 11 ISO using WindowsIsoDownloader
	Write-Output "Downloading Windows 11 iso file from Microsoft using WindowsIsoDownloader..."
	$isoDownloadProcess = (Start-Process ($toolsFolder + "WindowsIsoDownloader\WindowsIsoDownloader.exe") -NoNewWindow -Wait -WorkingDirectory ($toolsFolder + "WindowsIsoDownloader\") -PassThru)
}

#########################################################
    #         CREATE Tiny11 PROCESS STARTS          #    
#########################################################
if ($isoDownloadProcess.ExitCode -eq 0 -or $_local_image) {
	#Mount the Windows 11 ISO
	Write-Output "Mounting the original iso..."
	$mountResult = Mount-DiskImage -ImagePath $isoPath
	$isoDriveLetter = ($mountResult | Get-Volume).DriveLetter

	#Return and choose avaliable windows editions

	Write-Output "Checking ISO for available images..."
	$windowsImages = Get-WindowsImage -ImagePath ($isoDriveLetter + ":\sources\install.wim")
	
	#Getting the wanted image index
	if ($wantedImageName) {
		$wantedImageIndex = $windowsImages | Where-Object { $_.ImageName -eq $wantedImageName } | Select-Object -ExpandProperty ImageIndex
	}
	
	if (-not($wantedImageIndex)) {
		clear
		callBack-MSG-processStarts
		Write-Output "Failed to find image with name '$wantedImageName'"
		Write-Output "Select a number from the Available Images list below`n"

		Write-Output "[0]. Abort the process"
		$imageIndex = 1
		$windowsImages | ForEach-Object {
			Write-Output "[$imageIndex]. $($_.ImageName)"
			$imageIndex++
		}

		$selectedImageIndex = [int](Read-Host -Prompt "`nSelect an image by entering its corresponding number`nYour choice")
		if ($selectedImageIndex -lt 1) {			
			Write-Output "Unmounting the mounted iso..."
			Dismount-DiskImage -ImagePath $isoPath | Out-Null
	
			Write-Output "Exiting..."

			return
		}

		while ($selectedImageIndex -gt $windowsImages.Count) {
			$selectedImageIndex = [int](Read-Host -Prompt "Please choose a valid image number`nYour choice")
		}

		$wantedImage = $windowsImages[$selectedImageIndex - 1]
		$wantedImageName = $wantedImage.ImageName
		$wantedImageIndex = $wantedImage.ImageIndex
		Write-Output "`nSelected Image: $wantedImageName`n"
	}

	#Creating needed temporary folders
	Write-Output "Creating temporary folders...`n"
	New-Item -ItemType Directory -Force -Path $isoFolder | Out-Null
	New-Item -ItemType Directory -Force -Path $installImageFolder | Out-Null
	New-Item -ItemType Directory -Force -Path $bootImageFolder | Out-Null

	################# Beginning of install.wim patches ##################

	#Copying the ISO files to the ISO folder
	Write-Output "Copying the content of the original iso to the work folder..."
	cp -Recurse ($isoDriveLetter + ":\*") $isoFolder | Out-Null

	#Unmounting the original ISO since we don't need it anymore (we have a copy of the content)
	Write-Output "Unmounting the original iso..."
	Dismount-DiskImage -ImagePath $isoPath | Out-Null

	#Mounting the WIM image
	Write-Output "Mounting the install.wim image..."
	Set-ItemProperty -Path ($isoFolder + "sources\install.wim") -Name IsReadOnly -Value $false | Out-Null
	Mount-WindowsImage -ImagePath ($isoFolder + "sources\install.wim") -Path $installImageFolder -Index $wantedImageIndex | Out-Null

	#Detecting provisionned app packages
	Write-Output "Removing unwanted app packages from the install.wim image..."
	$detectedProvisionnedPackages = Get-AppxProvisionedPackage -Path $installImageFolder

	#Removing unwanted provisionned app packages
	foreach ($detectedProvisionnedPackage in $detectedProvisionnedPackages) {
		foreach ($unwantedProvisionnedPackage in $unwantedProvisionnedPackages) {
			if ($detectedProvisionnedPackage.PackageName.Contains($unwantedProvisionnedPackage)) {
				Remove-AppxProvisionedPackage -Path $installImageFolder -PackageName $detectedProvisionnedPackage.PackageName -ErrorAction SilentlyContinue | Out-Null
			}
		}
	}

	#Detecting windows packages
	Write-Output "Removing unwanted windows packages from the install.wim image..."
	$detectedWindowsPackages = Get-WindowsPackage -Path $installImageFolder

	#Removing unwanted windows packages
	foreach ($detectedWindowsPackage in $detectedWindowsPackages) {
		foreach ($unwantedWindowsPackage in $unwantedWindowsPackages) {
			if ($detectedWindowsPackage.PackageName.Contains($unwantedWindowsPackage)) {
				Remove-WindowsPackage -Path $installImageFolder -PackageName $detectedWindowsPackage.PackageName -ErrorAction SilentlyContinue | Out-Null
			}
		}
	}

	Write-Output "Deleting PathsToDelete from the install.wim image..."
	foreach ($pathToDelete in $pathsToDelete) {
		$fullpath = ($installImageFolder + $pathToDelete.Path)

		if ($pathToDelete.IsFolder -eq $true) {
			takeown /f $fullpath /r /d $yes | Out-Null
			icacls $fullpath /grant ("$env:username"+":F") /T /C | Out-Null
			Remove-Item -Force $fullpath -Recurse -ErrorAction SilentlyContinue | Out-Null
		} else {
			takeown /f $fullpath | Out-Null
			icacls $fullpath /grant ("$env:username"+":F") /T /C | Out-Null
			Remove-Item -Force $fullpath -ErrorAction SilentlyContinue | Out-Null
		}
	}

	# Loading the registry from the mounted WIM image
	Write-Output "Patching the registry in the install.wim image..."
	reg load HKLM\installwim_DEFAULT ($installImageFolder + "Windows\System32\config\default") | Out-Null
	reg load HKLM\installwim_NTUSER ($installImageFolder + "Users\Default\ntuser.dat") | Out-Null
	reg load HKLM\installwim_SOFTWARE ($installImageFolder + "Windows\System32\config\SOFTWARE") | Out-Null
	reg load HKLM\installwim_SYSTEM ($installImageFolder + "Windows\System32\config\SYSTEM") | Out-Null

	# Applying following registry patches on the system image:
	#	Bypassing system requirements
	#	Disabling Teams
	#	Disabling Sponsored Apps
	#	Enabling Local Accounts on OOBE
	#	Disabling Reserved Storage
	#	Disabling Chat icon
	regedit /s ./tools/installwim_patches.reg | Out-Null

	# Unloading the registry
	reg unload HKLM\installwim_DEFAULT | Out-Null
	reg unload HKLM\installwim_NTUSER | Out-Null
	reg unload HKLM\installwim_SOFTWARE | Out-Null
	reg unload HKLM\installwim_SYSTEM | Out-Null

	#Copying the setup config file
	Write-Output "Placing the autounattend.xml file in the install.wim image..."
	[System.IO.File]::Copy((Get-ChildItem .\tools\autounattend.xml).FullName, ($installImageFolder + "Windows\System32\Sysprep\autounattend.xml"), $true) | Out-Null

	#Unmount the install.wim image
	Write-Output "Unmounting the install.wim image..."
	Dismount-WindowsImage -Path $installImageFolder -Save | Out-Null

	#Moving the wanted image index to a new image
	Write-Output "Creating a clean install.wim image without all unnecessary indexes..."
	Export-WindowsImage -SourceImagePath ($isoFolder + "sources\install.wim") -SourceIndex $wantedImageIndex -DestinationImagePath ($isoFolder + "sources\install_patched.wim") -CompressionType max | Out-Null

	#Delete the old install.wim and rename the new one
	rm ($isoFolder + "sources\install.wim") | Out-Null
	Rename-Item -Path ($isoFolder + "sources\install_patched.wim") -NewName "install.wim" | Out-Null
	################# Ending of install.wim patches ##################

	################# Beginning of boot.wim patches ##################
	Set-ItemProperty -Path ($isoFolder + "sources\boot.wim") -Name IsReadOnly -Value $false | Out-Null
	Write-Output "Mounting the boot.wim image..."
	Mount-WindowsImage -ImagePath ($isoFolder + "sources\boot.wim") -Path $bootImageFolder -Index 2 | Out-Null

	Write-Output "Patching the registry in the boot.wim image..."
	reg load HKLM\bootwim_DEFAULT ($bootImageFolder + "Windows\System32\config\default") | Out-Null
	reg load HKLM\bootwim_NTUSER ($bootImageFolder + "Users\Default\ntuser.dat") | Out-Null
	reg load HKLM\bootwim_SYSTEM ($bootImageFolder + "Windows\System32\config\SYSTEM") | Out-Null

	# Applying following registry patches on the boot image:
	#	Bypassing system requirements
	regedit /s ./tools/bootwim_patches.reg | Out-Null

	reg unload HKLM\bootwim_DEFAULT | Out-Null
	reg unload HKLM\bootwim_NTUSER | Out-Null
	reg unload HKLM\bootwim_SYSTEM | Out-Null

	#Unmount the boot.wim image
	Write-Output "Unmounting the boot.wim image..."
	Dismount-WindowsImage -Path $bootImageFolder -Save | Out-Null

	#Moving the wanted image index to a new image
	Write-Output "Creating a clean boot.wim image without all unnecessary indexes..."
	Export-WindowsImage -SourceImagePath ($isoFolder + "sources\boot.wim") -SourceIndex 2 -DestinationImagePath ($isoFolder + "sources\boot_patched.wim") -CompressionType max | Out-Null

	#Delete the old boot.wim and rename the new one
	rm ($isoFolder + "sources\boot.wim") | Out-Null
	Rename-Item -Path ($isoFolder + "sources\boot_patched.wim") -NewName "boot.wim" | Out-Null
	################# Ending of boot.wim patches ##################

	#Copying the setup config file to the iso copy folder
	[System.IO.File]::Copy((Get-ChildItem .\tools\autounattend.xml).FullName, ($isoFolder + "autounattend.xml"), $true) | Out-Null

	#Building the new trimmed and patched iso file
	Write-Output "Building the tiny11.iso file..."
	.\tools\oscdimg.exe -m -o -u2 -udfver102 -bootdata:("2#p0,e,b" + $isoFolder + "boot\etfsboot.com#pEF,e,b" + $isoFolder + "efi\microsoft\boot\efisys.bin") $isoFolder $tinyPath | Out-Null
} else {
	Write-Output "Unable to build the tiny11 iso (an error occured while trying to download the original iso using WindowsIsoDownloader)."
}

#Cleaning the folders used during the process
Write-Output "Removing work folders..."
Remove-Item $rootWorkdir -Force -Recurse -ErrorAction SilentlyContinue | Out-Null
