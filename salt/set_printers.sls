# Call this so: salt 'winminion' state.apply set_printers pillar='{"printers": ["Office", "Lab", "Reception"], "default":"Office" }'

{% set printers = pillar.get('printers', []) %}
{% set default  = pillar.get('default', '') %}
{% set base_url = "http://printserver:631/printers/" %}
{% set desired_urls = [] %}

{% for p in printers %}
{% do desired_urls.append(base_url ~ p) %}
{% endfor %}

# 1. Install desired printers
{% for p in printers %}

install_{{ p }}:
  cmd.run:
    - shell: powershell
    - name: |
        $name = "{{ p }}"
        $url  = "{{ base_url }}{{ p }}"

        if (-not (Get-Printer | Where-Object {$_.Name -eq $name})) {
            Add-Printer -Name $name -PortName $url -DriverName "Microsoft IPP Class Driver"
        }

{% endfor %}


# 2. Remove not desired printer
cleanup_printers:
  cmd.run:
    - shell: powershell
    - name: |
        $desired = @({% for u in desired_urls %} "{{ u }}"{% if not loop.last %},{% endif %} {% endfor %})

        Get-Printer | ForEach-Object {
            $printer = $_

            # nur Netzwerkdrucker (IPP/HTTP etc.)
            if ($printer.PortName -like "http*") {
                if ($desired -notcontains $printer.PortName) {
                    Remove-Printer -Name $printer.Name
                }
            }
        }

# 3. Set default printer
set_default_printer:
  cmd.run:
#   - shell: powershell
#   - name: |
#       $Printer = Get-CimInstance -Class Win32_Printer -Filter "Name='{{ default }}'"
#       Invoke-CimMethod -InputObject $Printer -MethodName SetDefaultPrinter
     - name: rundll32 printui.dll,PrintUIEntry /y /n "{{default}}"

