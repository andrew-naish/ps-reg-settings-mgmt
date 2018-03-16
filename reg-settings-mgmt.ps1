# Get's settings from a provided registry path, path created if it does not exist.
function Get-ApplicationSettings {

    param (
        [Parameter(Mandatory=$true)]
        [String] $Path
    )

    ## Init

    function Get-RegKeyAsHashtable ($Path) { 

        # modified from: https://github.com/andyn922/powershell-resource/blob/master/Get-RegKeyAsHashtable.ps1

        $regkey_properties = ( Get-ItemProperty $Path ).PSBase.Properties | 
            Where-Object { $_.Name -inotlike "PS*" }
        $return = @{}

        $regkey_properties | ForEach-Object {  
            $return.Add("$($_.Name)", "$($_.Value)") 
        } 
        
        return $return 

    }

    if ( !(Test-Path $Path)) { 
        Write-Warning "Path did not exist, twas created."
        New-Item $Path | Out-Null }

    ## Main

    $GLOBAL:application_settings_reg_key = $Path
    $GLOBAL:application_settings = Get-RegKeyAsHashtable -Path $GLOBAL:application_settings_reg_key
    $GLOBAL:application_settings_to_update = @{}

    if ($application_settings.Count -eq 0) {
        Write-Warning "No settings at the key you provided." }

}

# Adds or Updates a new/existing setting.
function Add-ApplicationSettings ($Name, $Value) {

    if ($GLOBAL:application_settings_to_update.ContainsKey("$Name")) {
        $GLOBAL:application_settings_to_update.Remove("$Name")
    }

    $GLOBAL:application_settings_to_update.Add($Name, $Value)

}

# Provide the setting name to '$Name' it will return the setting if it has value.
#  if the setting has no value, you can provide a scriptblock to '$UpdateExpression'
#  the value of the scriptblock will be returned and be staged as the settings' value.
function Resolve-ApplicationSettings {
    
    param(

        [Parameter(Mandatory=$true)]
        [String] $Name,

        [Parameter(Mandatory=$false)]
        [ScriptBlock] $UpdateExpression,

        [Parameter(Mandatory=$false)]
        [Switch] $ForceUpdate

    )

    Begin {

        $setting_name = $Name
        $setting_value = $GLOBAL:application_settings."$setting_name"
    }

    ## Main

    Process {

        if ( ([String]::IsNullOrEmpty( $setting_value ) -OR $ForceUpdate) -AND $UpdateExpression ) {

            try {
                $expression_result = Invoke-Command $UpdateExpression -NoNewScope
                Add-ApplicationSettings -Name "$setting_name" -Value "$expression_result"
            } catch {
                $expression_result = $null
                Write-Warning "Update expression failed, returning null"
            }

            return $expression_result

        } 

        else { 

            return $setting_value 

        }

    } # end Process

}

# Commits setting changes made with 'Add-ApplicationSettings' or 'Resolve-ApplicationSettings'
function Update-ApplicationSettings {

    $GLOBAL:application_settings_to_update.GetEnumerator() | ForEach-Object {
        $o = New-ItemProperty $GLOBAL:application_settings_reg_key -Force `
                -Name  "$($_.Key)" `
                -Value "$($_.Value)"
    };

}