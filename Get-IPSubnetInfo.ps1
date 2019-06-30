
<#
	.SYNOPSIS
		Returns basic IP subnet information based on supplied NetworkAddress and mask
	
	.DESCRIPTION
		This function will take an IP NetworkAddress and subnet mask conbination as input and return basic
		information about the subnet including first and last usable IP addresses
	
	.PARAMETER NetworkAddress
		NetworkAddress in CIDR format ( xxx.xxx.xxx.xxx/yy )
	
	.PARAMETER IPAddress
		A description of the IPAddress parameter.
	
	.PARAMETER SubnetMask
		A description of the SubnetMask parameter.
	
	.EXAMPLE
		PS C:\> Get-IPSubnetInfo -Address 10.152.17.240/22
		
		Address        : 10.152.17.240
        NetworkName    : 10.152.16.0/22
        NetworkAddress : 10.152.16.0
        NetworkMask    : 255.255.252.0
        MaskLength     : 22
        FirstIPAddress : 10.152.16.1
        LastIPAddress  : 10.152.19.254
	
	.EXAMPLE
		PS C:\> Get-IPSubnetInfo -IPAddress 10.152.17.240 -SubnetMask 255.255.252.0
		
		Address        : 10.152.17.240
        NetworkName    : 10.152.16.0/22
        NetworkAddress : 10.152.16.0
        NetworkMask    : 255.255.252.0
        MaskLength     : 22
        FirstIPAddress : 10.152.16.1
        LastIPAddress  : 10.152.19.254
	
	.OUTPUTS
		PSObject
	
	.NOTES
		Additional information about the function.
#>
function Get-IPSubnetInfo
{
    [CmdletBinding(DefaultParameterSetName = 'ByCIDR')]
    [OutputType([psobject], ParameterSetName = 'ByCIDR')]
    [OutputType([psobject], ParameterSetName = 'ByIPandMask')]
    [OutputType([psobject])]
    param
    (
        [Parameter(ParameterSetName = 'ByCIDR',
            Mandatory = $true)]
        [string[]]$Address,
        [Parameter(ParameterSetName = 'ByIPandMask',
            Mandatory = $true)]
        [IPAddress]$IPAddress,
        [Parameter(ParameterSetName = 'ByIPandMask',
            Mandatory = $true)]
        [IPAddress]$SubnetMask
    )
	
    begin
    {
    
    }

    process
    {
        <# 
        There is no built in -BAND -BOR -BXOR operators for [Byte[]] so this function is needed
        
        For instance, network address = IPAddress -BAND MaskAddress  
        #>		
        Function ByteArrayOperation
        {
            param
            (
                [byte[]]$array1,
                [byte[]]$array2,
                [string]$Operation
            )
			
            $ResultByteArray = [System.Byte[]]::new($array1.Length)
			
            for ($i = 0; $i -lt $ResultByteArray.Length; $i++)
            {
                if ($Operation -eq 'BAND') { $ResultByteArray[$i] = $array1[$i] -band $array2[$i] }
                if ($Operation -eq 'BXOR') { $ResultByteArray[$i] = $array1[$i] -bxor $array2[$i] }
                if ($Operation -eq 'BOR') { $ResultByteArray[$i] = $array1[$i] -bor $array2[$i] }
            }
			
            $ResultByteArray
        }
		
        switch ($pscmdlet.ParameterSetName)
        {
            'ByCIDR'
            {
                foreach ($SingleAddress in $Address)
                {
                    try
                    {
                        $AddressIP = [ipaddress]::Parse($SingleAddress.Split('/')[0])
                        $ParametersValidated = $true
                    }
                    catch
                    {
                        '{0} is invalid IP Address' -f $SingleAddress | Write-Error
                        $ParametersValidated = $false
                    }
                    
                    try
                    {
                        $MaskLength = [int]($SingleAddress.Split('/')[1])
                        $ParametersValidated = $ParametersValidated -and $true
                    }
                    catch
                    {
                        '{0} has invalid mask length' -f $SingleAddress | Write-Error
                        $ParametersValidated = $false
                    }
                    
                    if ($masklength -lt 1)
                    {
                        $ParametersValidated = $false
                        '{0} has mask length too small' -f $SingleAddress | Write-Error
                    }
                    
                    if ($ParametersValidated)
                    {
                        $MaskBytes = [byte[]]::new($AddressIP.GetAddressBytes().Length)
                        
                        $i = 0
                        do
                        {
                            if ($maskLength -ge ((1 + $i) * 8))
                            {
                                $MaskBytes[$i] = 255
                            }
                            else
                            {
                                $MaskBytes[$i] = (255 -shl ((1 + $i) * 8) - $maskLength) % 256
                            }
                            
                            $i++
                        }
                        while ($maskLength -gt ($i * 8))
                        
                        $MaskAddress = [IPAddress]::new($MaskBytes)
                        
                        $NetworkBytes = ByteArrayOperation $AddressIP.GetAddressBytes() $MaskBytes -Operation BAND
                        $NetworkAddress = [ipaddress]::new($NetworkBytes)
                        
                        if ($MaskBytes[-1] -le 252)
                        {
                            $FirstIPBytes = $NetworkAddress.GetAddressBytes()
                            $FirstIPBytes[-1] += 1
                            $FirstIPAddress = [ipaddress]::new($FirstIPBytes)
                            
                            $BroadcastBytes = [System.Byte[]]::new($FirstIPBytes.Length)
                            for ($i = 0; $i -lt $BroadcastBytes.Length; $i++) { $BroadcastBytes[$i] = 255 }
                            
                            $MaskBytes = $MaskAddress.GetAddressBytes()
                            
                            $HostBytes = ByteArrayOperation $MaskBytes $BroadcastBytes -Operation BXOR
                            $LastIPBytes = ByteArrayOperation $NetworkBytes $HostBytes -Operation BOR
                            
                            $LastIPBytes[-1] -= 1
                            
                            $LastIPAddress = [ipaddress]::new($LastIPBytes)
                        }
                        else
                        {
                            $FirstIPAddress = $null
                            $LastIPAddress = $null
                        }
                        
                        $obj = [pscustomobject][ordered] @{
                            Address        = $AddressIP
                            NetworkName    = $NetworkAddress.ToString() + '/' + $masklength
                            NetworkAddress = $NetworkAddress
                            NetworkMask    = $MaskAddress
                            MaskLength     = $masklength
                            FirstIPAddress = $FirstIPAddress
                            LastIPAddress  = $LastIPAddress
                        }
                        
                        $obj
                    }
                }        
            }

            'ByIPandMask'
            {
                # create CIDR address and call into self

                $MaskBytes = $SubnetMask.GetAddressBytes()

                $MaskLength = 0


                for ($i = 0; $i -lt $MaskBytes.Length; $i++)
                {
                    if ($MaskBytes[$i] -eq 255) 
                    { 
                        $MaskLength += 8 
                    }
                    elseif ($MaskBytes[$i] -gt 0)
                    {
                        $MaskLength += 8 - [Math]::Log((1 + ($MaskBytes[$i] -bxor 255)), 2)
                    }    
                }

                try
                {
                    $FinalMaskLength = [int]::Parse($MaskLength)
                }
                catch
                {
                    '{0} is not a valid subnet mask' -f $SubnetMask.ToString() | Write-Error
                }

                if ($FinalMaskLength)
                {
                    $CIDR = $IPAddress.ToString() + '/' + $FinalMaskLength

                    Get-IPSubnetInfo -Address $CIDR 
                }
            }
        }
    }
	
    end
    {
		
    }
}




