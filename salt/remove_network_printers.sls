remove_network_printers:
  cmd.run:
    - name: Get-Printer | Where-Object {$_.PortName -like "*printserver*"} | Remove-Printer
    - shell: powershel
