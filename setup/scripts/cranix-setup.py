#!/usr/bin/python3

import ipaddress
import os
import psutil
import tkinter as tk
from tkinter import ttk
from bashconfigparser import BashConfigParser

def ist_valide_ipv4(ip) -> bool:
    try:
        ipaddress.IPv4Address(ip)
        return True
    except ValueError:
        return False
    
def _(text):
    if language in translation:
        if text in translation[language]:
            return translation[language]
    return text

def list_physical_interfaces():
    # Holt alle Netzwerk-Schnittstellen
    gateways = psutil.net_if_addrs()
    interfaces = []
    for interface, snics in gateways.items():
        # Wir filtern virtuelle Schnittstellen (Loopback, Docker, veth etc.)
        if interface.startswith(('lo', 'docker', 'veth', 'br-', 'virbr')):
            continue
        ip=""
        mac=""
        # Suche nach der MAC-Adresse (Familie AF_PACKET unter Linux)
        for snic in snics:
            if snic.family == psutil.AF_LINK: # AF_LINK ist die MAC
                mac = snic.address
            if snic.family == 2: # AF_LINK ist die MAC
                ip = snic.address
        if mac != "":
            interfaces.append(f"{interface} {mac} {ip}")
    return interfaces

def showmessage(text: str):
    popup = tk.Toplevel(root)
    popup.title(_("Message"))
    popup.geometry("250x80")
    popup.grab_set()
    def confirm():
        popup.destroy()
    w = tk.Label(popup, justify="center", text=_(text))
    w.pack()
    b = tk.Button(popup, text="OK", command=confirm)
    b.pack()

def showerror(text: str, description: str = ""):
    popup = tk.Toplevel(root)
    popup.title(_("Error"))
    if description == "":
        popup.geometry("250x80")
    else:
        popup.geometry("250x120")
    popup.grab_set()
    def confirm():
        popup.destroy()
    w = tk.Label(popup, justify="center", text=_(text), fg="red")
    w.pack()
    if description != "":
        d = tk.Label(popup, justify="center", text=_(description))
        d.pack()
    b = tk.Button(popup, text="OK", command=confirm)
    b.pack()
        
def open_selection_popup(options, variable: tk.Entry):
       # 1. Das Popup-Fenster (Toplevel)
    popup = tk.Toplevel(root)
    popup.title("Option wählen")
    popup.geometry("500x450")
    popup.grab_set() # Fokus auf das Popup legen

    # 2. Container-Frame für Canvas und Scrollbar
    container = tk.Frame(popup)
    container.pack(fill="both", expand=True, padx=10, pady=10)

    # 3. Canvas erstellen
    canvas = tk.Canvas(container)
    scrollbar = ttk.Scrollbar(container, orient="vertical", command=canvas.yview)

    # 4. Der Frame, der die Radiobuttons tatsächlich hält
    scrollable_frame = tk.Frame(canvas)

    # Diese Funktion aktualisiert den Scroll-Bereich, wenn Buttons hinzugefügt werden
    scrollable_frame.bind(
        "<Configure>",
        lambda e: canvas.configure(scrollregion=canvas.bbox("all"))
    )

    # Den Frame in das Canvas Fenster einbetten
    canvas.create_window((0, 0), window=scrollable_frame, anchor="nw")
    canvas.configure(yscrollcommand=scrollbar.set)

    # Pack-Reihenfolge innerhalb des Containers
    canvas.pack(side="left", fill="both", expand=True)
    scrollbar.pack(side="right", fill="y")

    # 5. Radiobuttons hinzufügen
    # Variable für die Auswahl
    choice = tk.StringVar(value=variable.get())

    for value in options:
        tk.Radiobutton(scrollable_frame, text=_(value), variable=choice, value=value).pack(anchor="w", padx=20)

    # Mausrad-Unterstützung hinzufügen (optional aber empfohlen)
    def _on_mousewheel(event):
        canvas.yview_scroll(int(-1*(event.delta/120)), "units")

    canvas.bind_all("<MouseWheel>", _on_mousewheel)

    # 6. Bestätigen Button (unten fixiert, außerhalb des Scroll-Bereichs)
    def confirm():
        selected_value = choice.get()
        variable.config(state="normal")
        variable.delete(0, tk.END)
        if selected_value != "free_entry":
            variable.insert(0, selected_value)
            variable.config(state="readonly")
        popup.destroy()

    btn_ok = tk.Button(popup, text="Auswahl übernehmen", command=confirm, bg="#4CAF50", fg="white")
    btn_ok.pack(pady=10)

def open_type_selection():
    open_selection_popup(instTypes, entry_type)

def open_netmask_selection():
    open_selection_popup(netMasks, entry_netmask)
    
def open_ext_netmask_selection():
    open_selection_popup(netMasks, entry_ext_netmask)

def open_network_selection():
    open_selection_popup(networks, entry_network)
    
def open_intern_device_selection():
    open_selection_popup(interfaces, entry_device)

def open_ext_device_selection():
    open_selection_popup(interfaces, entry_ext_device)

# Hilfsfunktion für wiederkehrende Elemente

def create_field(label_text, row, column, is_password=False):
    # 'sticky="w"' sorgt für die Linksbündigkeit (West)
    lbl = tk.Label(root, text=_(label_text))
    lbl.grid(row=row*2, column=column, sticky="w", pady=(10, 0), padx=5)

    ent = tk.Entry(root, width=width, show="*" if is_password else "")
    ent.grid(row=row*2 + 1, column=column, sticky="ew", padx=5)
    return ent

def setup_server():
    if not check_values():
        return
    btn_save.config(state="disabled")
    btn_setup.config(state="disabled")
    btn_abort.config(state="disabled")
    showmessage("Start Setup")
    result = os.system("xterm -e '/usr/share/cranix/setup/scripts/crx-setup.sh --all 2>&1 | tee -a /var/log/cranix-setup.log'")
    print(result)
    exit()

def check_values() -> bool:
    name = entry_name.get()
    if name == "":
        showerror("Institute Name must not be empty")
        return False
    domain_name = entry_domain.get()
    if domain_name == "":
        showerror("Domain Name must not be empty")
        return False
    inst_type = entry_type.get()
    reg_code = entry_regcode.get()
    if reg_code == "":
        showerror("You have to provide a Registration Code.")
        return False
    is_valide = os.popen(f"curl --insecure -X GET https://repo.cephalix.eu/api/customers/regcodes/{reg_code}").read()
    if is_valide == "0":
        showerror("Regcode is not valide")
        return False
    pw1 = entry_pw.get()
    pw2 = entry_pw2.get()
    if pw1 == "" or pw1 != pw2:
        showerror("Password is bad")
        return False
    network = entry_network.get()
    if not ist_valide_ipv4(network):
        showerror("Network is not valide")
        return False
    netmask = entry_netmask.get()
    device = entry_device.get()
    if device == "":
        showerror("You have to select a internal network device!")
        return False
    device = device.split()[0]
    ext_ip = entry_ext_ip.get()
    if ext_ip != "dhcp" and not ist_valide_ipv4(ext_ip):
        showerror("External IP Address is not valide.", "You have to enter 'dhcp' or a valide IP address.")
        return False
    ext_netmask = entry_ext_netmask.get()
    ext_device = entry_ext_device.get()
    if ext_device == "":
        showerror("You have to select a external network device!")
        return False
    ext_device = ext_device.split()[0]
    ext_gateway = entry_ext_gateway.get()
    if ext_ip != "dhcp" and not ist_valide_ipv4(ext_gateway):
        showerror("External gateway IP is not valide.")
        return False
    #Write values
    with open("/root/passwd","w") as f:
        f.write(pw1)
    #TODO
    with open("/root/cpasswd","w") as f:
        f.write(pw1)
    int_ip = network.split(".")
    int_ip[3]="0"
    cranix_conf = BashConfigParser()
    cranix_conf.parse_file('/etc/sysconfig/cranix')
    cranix_conf.set('CRANIX_NAME', name)
    cranix_conf.set('CRANIX_DOMAIN', domain_name)
    cranix_conf.set('CRANIX_WORKGROUP', domain_name.split(".")[0].upper())
    cranix_conf.set('CRANIX_TYPE', inst_type)
    cranix_conf.set('CRANIX_REG_CODE', reg_code)
    cranix_conf.set('CRANIX_INTERNAL_DEVICE', device)
    cranix_conf.set('CRANIX_NETWORK', '.'.join(int_ip))
    cranix_conf.set('CRANIX_NETMASK', netmask)
    cranix_conf.set('CRANIX_SERVER_EXT_DEVICE', ext_device)
    cranix_conf.set('CRANIX_SERVER_EXT_IP', ext_ip)
    cranix_conf.set('CRANIX_SERVER_EXT_NETMASK', ext_netmask)
    cranix_conf.set('CRANIX_SERVER_EXT_GW', ext_gateway)
    int_ip[3]="2"
    cranix_conf.set('CRANIX_SERVER', '.'.join(int_ip))
    cranix_conf.set('CRANIX_NET_GATEWAY', '.'.join(int_ip))
    int_ip[3]="3"
    cranix_conf.set('CRANIX_FILESERVER', '.'.join(int_ip))
    int_ip[3]="4"
    cranix_conf.set('CRANIX_PRINTSERVER', '.'.join(int_ip))
    int_ip[3]="5"
    cranix_conf.set('CRANIX_MAILSERVER', '.'.join(int_ip))
    int_ip[3]="6"
    cranix_conf.set('CRANIX_PROXY', '.'.join(int_ip))
    int_ip[3]="7"
    cranix_conf.set('CRANIX_BACKUP_SERVER', '.'.join(int_ip))
    int_ip[3]="0"
    cranix_conf.set('CRANIX_SERVER_NET', "{0}/{1}".format('.'.join(int_ip),"24"))
    int_ip[2]="1"
    cranix_conf.set('CRANIX_ANON_DHCP_NET', "{0}/{1}".format('.'.join(int_ip),"24"))
    int_ip[2]="2"
    cranix_conf.set('CRANIX_FIRST_ROOM_NET', '.'.join(int_ip))
    int_ip[2]="1"
    start_ip = '.'.join(int_ip)
    int_ip[3]="255"
    end_ip = '.'.join(int_ip)
    cranix_conf.set('CRANIX_ANON_DHCP_RANGE', f"{start_ip} {end_ip}")
    cranix_conf.save()
    return True

width=35
language="de"
translation={}
instTypes =  [ "work", "global", "primary", "gymnasium", "secondary", "real", "special", "other", "administration", "business" ]
netMasks = ["8","9","10","11","12","13","14","15","16","17","18","19","20","21","22","23","24"]
networks = ["free_entry", "172.16.0.0", "172.17.0.0", "172.18.0.0", "172.19.0.0", "172.20.0.0", "172.21.0.0", "172.22.0.0", "172.23.0.0", "172.24.0.0", "172.25.0.0", "172.26.0.0", "172.27.0.0", "172.28.0.0", "172.29.0.0", "172.30.0.0", "172.31.0.0"]
interfaces = list_physical_interfaces()
entry_name: tk.Entry
entry_domain: tk.Entry
entry_type: tk.Entry
entry_ip: tk.Entry
entry_netmask: tk.Entry
entry_regcode: tk.Entry
entry_device: tk.Entry
entry_ext_ip: tk.Entry
entry_ext_netmask: tk.Entry
entry_ext_device: tk.Entry
entry_ext_gateway: tk.Entry

if __name__ == '__main__':
    root = tk.Tk()
    root.title("CRANIX Configuration")
    root.geometry("640x400")
    # Fields on the left side
    entry_name = create_field("Institute Name:", 0, 0)
    entry_domain = create_field("Domain Name:", 1, 0)
    
    btn_type = tk.Button(root, text=_("Select Institute Type"), command=open_type_selection).grid(row=4, column=0, sticky="w", padx=5, pady=(10,0))
    entry_type   = tk.Entry(root, width=width)
    entry_type.grid(row=5, column=0)
    entry_type.insert(0,'gymnasium')
    entry_type.config(state="readonly")
    
    entry_regcode = create_field("Registration Code:", 3, 0)
    entry_pw = create_field("Administrator Password:", 4, 0, is_password=True)
    entry_pw2 = tk.Entry(root, width=width, show="*")
    entry_pw2.grid(row=10, column=0)
    
    # Fields on the right side
    btn_ipaddress = tk.Button(root, text=_("Select Internal Network"), command=open_network_selection).grid(row=0, column=1, sticky="w", padx=5, pady=(10,0))
    entry_network = tk.Entry(root, width=width)
    entry_network.grid(row=1, column=1)
    entry_network.insert(0,"172.16.0.0")
    entry_network.config(state="readonly")
    
    btn_netmask = tk.Button(root, text=_("Netmask"), command=open_netmask_selection).grid(row=0, column=2, sticky="w", padx=(0,5), pady=(10,0))
    entry_netmask = tk.Entry(root, width=10)
    entry_netmask.grid(row=1, column=2, sticky="w")
    entry_netmask.insert(0,"16")
    entry_netmask.config(state="readonly")
    
    btn_int_device = tk.Button(root, text=_("Select Internal Device"), command=open_intern_device_selection).grid(row=2, column=1, sticky="w", padx=5, pady=(10,0))
    entry_device = tk.Entry(root, width=width, state="readonly")
    entry_device.grid(row=3, column=1)
    
    entry_ext_ip = create_field("External IP:", 2, 1)
    entry_ext_ip.insert(0,"192.168.178.2")
    
    btn_ext_netmask = tk.Button(root, text=_("Netmask"), command=open_ext_netmask_selection).grid(row=4, column=2, sticky="w", padx=(0,5), pady=(10,0))
    entry_ext_netmask = tk.Entry(root, width=10)
    entry_ext_netmask.grid(row=5, column=2, sticky="w")
    entry_ext_netmask.insert(0,"24")
    entry_ext_netmask.config(state="readonly")
    
    btn_ext_device = tk.Button(root, text=_("Select External Device"), command=open_ext_device_selection).grid(row=6, column=1, sticky="w", padx=5, pady=(10,0))
    entry_ext_device = tk.Entry(root, width=width, state="readonly")
    entry_ext_device.grid(row=7, column=1)
    
    entry_ext_gateway = create_field("External Gateway:", 4, 1)
    entry_ext_gateway.insert(0,"192.168.178.1")
    # Last button    
    btn_save  = tk.Button(root, text=_("Save"), command=check_values)
    btn_save.grid(row=12, column=0, pady=15)
    btn_setup = tk.Button(root, text=_("Setup"), command=setup_server)
    btn_setup.grid(row=12, column=1, pady=15)
    btn_abort = tk.Button(root, text=_("Abort"), command=exit)
    btn_abort.grid(row=12, column=2, pady=15)
    
    root.mainloop()
