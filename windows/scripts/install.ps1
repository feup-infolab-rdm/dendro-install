﻿param (
    #[string]$price = 100,
    #[string]$ComputerName = $env:computername,
    #[string]$username = $(throw "-username is required."),
    #[string]$password = $( Read-Host -asSecureString "Input password" ),
    [switch]$t = $false,
	[switch]$c = $false,
	[switch]$j = $false,
	[switch]$u = $false,
	[switch]$s = $false,
	[switch]$d = $false,
	[switch]$r = $false,
	[string]$b
)

#function to zip a directory into a target zip folder
function ZipFiles( $tarGzfilename, $sourcedir )
{
    echo "Zipping folder "  $sourcedir  " into file "  $tarGzfilename;

    #source dir
    $sourceDirName = Split-Path $sourcedir -Leaf
    $sourceDirParent=(get-item $sourcedir).Parent.FullName

    #tar file
    $tarGzFileName = Split-Path $tarGzfilename -Leaf

    #compress the package
    If (Test-Path $sourcedir){

      If (Test-Path $tarGzfilename){
        rm $tarGzfilename
      }

      $prev = $PWD
      cd ..
      .\windows\libarchive\bin\bsdtar.exe cfzv $tarGzfilename scripts
      cd $prev
    }
    Else
    {
      echo "File "$tarfileName" does not exist. There was likely an error compressing it. Aborting setup."
      exit 1
    }

}

# define vagrant environment variables
./scripts/define_env_vars.ps1

$ENV:VAGRANT_VM_INSTALL='true'

# read shell arguments to pass to vagrant script
	$VAGRANT_SHELL_ARGS=''

	foreach ($key in $MyInvocation.BoundParameters.keys)
	{
		$value = (get-variable $key).Value 
		
		if($value -eq $TRUE)
		{
			$VAGRANT_SHELL_ARGS=$VAGRANT_SHELL_ARGS + "-$key ";
		}
		elseif($value -ne $FALSE)	
		{
			$VAGRANT_SHELL_ARGS=$VAGRANT_SHELL_ARGS + "-$key $value";
		}
	}

	echo "passed arguments: "$VAGRANT_SHELL_ARGS
    $ENV:VAGRANT_SHELL_ARGS = $VAGRANT_SHELL_ARGS

    #scripts zip file
    $targetZipFile = (get-item $PWD).Parent.FullName + "\scripts.tar.gz";

#source scripts folder
    $sourceScriptsFolder = (get-item $PWD).Parent.FullName + "\scripts";

# delete existing scripts zip if exists
if([System.IO.File]::Exists($targetZipFile)){
    del $targetZipFile
}

#zip scripts folder
ZipFiles $targetZipFile $sourceScriptsFolder;

echo "Booting up machine " $ENV:VAGRANT_VM_NAME
     " with IP " + $ENV:VAGRANT_VM_IP
     " and arguments " + $ENV:VAGRANT_SHELL_ARGS;

cd (get-item $PWD).Parent.FullName

# vagrant box update &&
vagrant up --provider virtualbox --provision
if ($? -ne 1)
{
	echo "Unable to bring vagrant VM up"
	exit 1
}

echo "Cleaning up..."

If (Test-Path $targetZipFile){
  del $targetZipFile
}

echo "Deleted temporary scripts package."

echo "Dendro setup complete."
