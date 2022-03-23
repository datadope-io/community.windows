#!powershell

# Copyright: (c) 2022, DataDope (@datadope-io)
# GNU General Public License v3.0+ (see COPYING or https://www.gnu.org/licenses/gpl-3.0.txt)

#AnsibleRequires -CSharpUtil Ansible.Basic

$spec = @{
    options = @{
        date_format = @{ type = 'str'; default = '%c' }
        tcp_filter = @{ type = 'list'; default = 'Listen' }
    }
    supports_check_mode = $false
}

$module = [Ansible.Basic.AnsibleModule]::Create($args, $spec)

$date_format = $module.Params.date_format
$tcp_filter = $module.Params.tcp_filter

# Structure of the response the script will return
$ansibleFacts = @{
    tcp_listen = @()
    udp_listen = @()
}

# Build an index of the processes based on the PID
$processes = @{}
Get-Process -IncludeUserName | ForEach-Object {
    $processes[$_.Id] = $_
}

# Format the given date with the same format as listen_port_facts stime (Date and time - abbreviated) by default, or
# with the given format
function Format-Date {
    param (
        $date
    )

    if ($date -ne $null) {
        $date = Get-Date $date -UFormat $date_format
    }

    return $date
}

# Return the processed listener and the associated PID data
function Build-Listener {
    param (
        $listener,
        $type
    )

    return @{
        address = $listener.LocalAddress
        name = $processes[[int]$listener.OwningProcess].ProcessName
        pid = $listener.OwningProcess
        port = $listener.LocalPort
        protocol = $type
        stime = Format-Date $processes[[int]$listener.OwningProcess].StartTime
        user = $processes[[int]$listener.OwningProcess].UserName
    }
}

try {
    # Retrieve the information of the TCP ports with Listen status by default, or with the given state/s
    Get-NetTCPConnection -State $tcp_filter -ErrorAction SilentlyContinue | Foreach-Object {
        $ansibleFacts.tcp_listen += Build-Listener $_ "tcp"
    }

    # Retrieve the information of the UDP ports
    Get-NetUDPEndpoint | Foreach-Object {
        $ansibleFacts.udp_listen += Build-Listener $_ "udp"
    }
} catch {
    $module.FailJson("An error occurred while retrieving ports facts: $($_.Exception.Message)", $_)
}

$module.Result.ansible_facts = $ansibleFacts
$module.ExitJson()
