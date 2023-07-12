#Defining preferences variables
clear
Write-Output "Loading configuration from config.json..."
$config = (Get-Content "config.json" -Raw) | ConvertFrom-Json
$wantedImageName = $config.WantedWindowsEdition
$unwantedProvisionnedPackages = $config.ProvisionnedPackagesToRemove
$unwantedWindowsPackages = $config.WindowsPackagesToRemove
$pathsToDelete = $config.PathsToDelete
$windowsIsoDownloaderReleaseUrl = $config.WindowsIsoDownloaderReleaseUrl

###########################################
##          Prepare the process          ##
###########################################
Write-Output "..............................................................................................`n"
Write-Output "Would you like to change the work directory? DEFAULT is C:\tiny11\ `n[This will decide downloaded windows image as well ex: c:\windows11.iso]`n" 
Write-Output "[1] Use the default path `n[2] Change default path`n"
$_choose_path = Read-Host -Prompt "Please select option: " 
$_choose_path = $_choose_path -replace " ",""
while ( -not($_choose_path -ge 1 -and $_choose_path -le 2) ) {
	$_choose_path = Read-Host -Prompt 'Please choose valid option: '
}
if ($_choose_path  -eq "2") {
	$rootWorkdir = Read-Host -Prompt "`nPlease insert the your work directory ex [ c:\`nYour Path ]"
	while ( -not (Test-Path -Path $rootWorkdir) ) {
		$rootWorkdir = Read-Host -Prompt "Please insert the valid directory path will be assign`nYour Path"
	}
	if (-not $rootWorkdir.EndsWith("\")) {
		$rootWorkdir = $rootWorkdir + "\tiny11\"
	}
	else {
		$rootWorkdir = $rootWorkdir + "tiny11\"
	}
}

# Write-Output "Creating needed variables..."
$rootWorkdir = if (-not($rootWorkdir)) {"c:\tiny11\"} else {$rootWorkdir}
$isoFolder = $rootWorkdir + "iso\"
$installImageFolder = $rootWorkdir + "installimage\"
$bootImageFolder = $rootWorkdir + "bootimage\"
$toolsFolder = $rootWorkdir + "tools\"
$isoPath =  (Split-Path $rootWorkdir -Parent).ToString() + "windows11.iso"
$tinyPath = (Split-Path $isoPath -Parent ).ToString() + "tiny11.iso"
$yes = (cmd /c "choice <nul 2>nul")[1]
#The $yes variable gets the "y" from "yes" (or corresponding letter in the language your computer is using).
#It is used to answer automatically to the "takeown" command, because the answer choices are localized which is not handy at all.
clear
Write-Output "`n..............................................................................................`n"
Write-Output "WORKDIR Path: $rootWorkdir"
Write-Output "`n..............................................................................................`n"
Write-Output "Would you like to download the latest version of Windows 11 or provide your own ISO file" 
Write-Output "[1] Download `n[2] Provide ISO File" 
$_choose_image = Read-Host -Prompt 'Choose option: '
$_choose_image = $_choose_image -replace " ",""
while ( -not($_choose_image -ge 1 -and $_choose_image -le 2) ) {
	$_choose_image = Read-Host -Prompt 'Please choose valid option: '
}
if ($_choose_image -eq "2") {
	$isoPath =  Read-Host -Prompt "Please insert the ISO path location Example: c:\windows11.iso`n" 
	while  ( (-not(Test-Path -Path $isoPath -PathType Leaf)) -or  (-not($isoPath.EndsWith(".iso"))) ) {
		$isoPath =  Read-Host -Prompt "This file doesn't exist or not valid please insert valid ISO File path`n"
	}
	$_local_image = "true"
	$tinyPath = (Split-Path $isoPath -Parent ).ToString() + "tiny11.iso"
}
# Confirmation
while ($_confirm_user -notlike "*y" -and $_confirm_user -notlike "*n") {
	clear
	Write-Output "`n..............................................................................................`n"
	Write-Output "WORKDIR: $rootWorkdir [<- Will be removed after process.]`nISO Windows: $isoPath `nTiny11 ISO Image: $tinyPath"
	Write-Output "`n..............................................................................................`n"
	$_confirm_user = Read-Host "`nPlease choose one of these options? [y] or [n]"
}
if ($_confirm_user -like "n" ) {
	clear
	Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
	.\tiny11creator.ps1
}
# Start download incase user_input download else gonna pass
if ($_choose_image -eq "1")  {
	md $rootWorkdir | Out-Null
	md ($toolsFolder + "WindowsIsoDownloader\") | Out-Null

	Write-Output "Downloading WindowsIsoDownloader release from GitHub..."
	Invoke-WebRequest -Uri $windowsIsoDownloaderReleaseUrl -OutFile WindowsIsoDownloader.zip
	Write-Output "Extracting WindowsIsoDownloader release..."
	Expand-Archive -Path WindowsIsoDownloader.zip -DestinationPath ($toolsFolder + "WindowsIsoDownloader\") -Force
	Remove-Item WindowsIsoDownloader.zip | Out-Null

	Write-Output "$toolsFolder"+"WindowsIsoDownloader\config.json"
	# set new download location for Windows11.ISO
	$_json_config_path = Join-Path -path $toolsFolder -ChildPath "WindowsIsoDownloader\config.json"
	$json = get-content $_json_config_path  | ConvertFrom-Json
	$json.DownloadFolder = (Split-Path $rootWorkdir -Parent).ToString()
	ConvertTo-Json $json -Depth 10 | Out-File $_json_config_path -Force
	
	# # Downloading the Windows 11 ISO using WindowsIsoDownloader
	Write-Output "Downloading Windows 11 iso file from Microsoft using WindowsIsoDownloader..."
	$isoDownloadProcess = (Start-Process ($toolsFolder + "WindowsIsoDownloader\WindowsIsoDownloader.exe") -NoNewWindow -Wait -WorkingDirectory ($toolsFolder + "WindowsIsoDownloader\") -PassThru)
}


if ($isoDownloadProcess.ExitCode -eq 0 -or $_local_image) {
	#Mount the Windows 11 ISO
	Write-Output "Mounting the original iso..."
	$mountResult = Mount-DiskImage -ImagePath $isoPath
	$isoDriveLetter = ($mountResult | Get-Volume).DriveLetter

	#Creating needed temporary folders
	Write-Output "Creating temporary folders..."
	md $isoFolder | Out-Null
	md $installImageFolder | Out-Null
	md $bootImageFolder | Out-Null

	#Copying the ISO files to the ISO folder
	Write-Output "Copying the content of the original iso to the work folder..."
	cp -Recurse ($isoDriveLetter + ":\*") $isoFolder | Out-Null

	#Unmounting the original ISO since we don't need it anymore (we have a copy of the content)
	Write-Output "Unmounting the original iso..."
	Dismount-DiskImage -ImagePath $isoPath | Out-Null

	################# Beginning of install.wim patches ##################
	#Getting the wanted image index
	$wantedImageIndex = Get-WindowsImage -ImagePath ($isoFolder + "sources\install.wim") | where-object { $_.ImageName -eq $wantedImageName } | Select-Object -ExpandProperty ImageIndex

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
