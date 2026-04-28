{% set printer = pillar.get('name', 'DefaultPrinter') %}

install_ipp_printer_{{ printer }}:
  cmd.run:
    - shell: powershell
    - name: Add-Printer -Name "{{ printer }}" -DriverName "Microsoft IPP Class Driver" -PortName "http://printserver:631/printers/{{ printer }}"
