# Dell C1760nw Printer Install

## What This Is

Automated installer for the Dell C1760nw color laser printer on Debian/Ubuntu-based Linux.

The Dell C1760nw is a rebranded Xerox Phaser 6000B. It uses **HBPLv1** (Host-Based Printer Language version 1) over RAW socket (JetDirect port 9100). It does **not** support PostScript, PCL, IPP Everywhere, Samsung SPL-C/QPDL, or HBPLv2.

## How to Install the Printer

```bash
sudo ./install-dell-c1760nw.sh              # default IP: 192.168.4.30
sudo ./install-dell-c1760nw.sh 10.0.0.50    # custom IP
```

## How to Print

```bash
lp -d DellC1760nw file.pdf                      # monochrome (default)
lp -d DellC1760nw -o ColorMode=Color file.pdf    # color
echo 'Hello' | lp -d DellC1760nw                 # quick test
lpstat -p DellC1760nw                             # check status
```

## Key Technical Details

- **Driver**: `foo2hbpl1` from https://github.com/mikerr/foo2zjs.git (mikerr fork)
- **PPD**: `Dell-C1760.ppd` from that same repo
- **Filter pipeline**: CUPS → foomatic-rip → foo2hbpl1-wrapper → Ghostscript → foo2hbpl1 → socket backend
- **Upstream bug**: The `foo2hbpl1-wrapper` script has an undefined `$SCREEN` variable that causes Ghostscript to fail on color jobs. The install script patches this with sed.
- **CMS/CRD files**: Color management PostScript files installed to `/usr/share/foo2hbpl/crd/` from the repo's `crd/qpdl/` and `crd/zjs/` directories.
- **Build dependency**: `libjbig-dev` (JBIG1 compression library) required to compile `foo2hbpl1`.

## If Claude Code is Asked to Install This Printer

Run the install script with sudo. The script handles everything: dependencies, building the driver from source, patching the wrapper bug, installing color management files, and configuring the CUPS queue. If the script fails:

1. Check network reachability: `timeout 3 bash -c "echo > /dev/tcp/PRINTER_IP/9100"`
2. Check CUPS: `systemctl status cups`
3. Check the filter: `echo '%!PS' | foo2hbpl1-wrapper -c 2>&1 | head -c 100` (should produce binary HBPLv1 data, not errors)
4. Check CUPS logs: `sudo grep "Job" /var/log/cups/error_log | tail -20`

## Things That Do NOT Work With This Printer

- Samsung SPL-C / rastertospl (wrong protocol entirely)
- foo2qpdl / Samsung CLP-365 driver (wrong protocol)
- foo2hbpl2 / HBPLv2 (wrong HBPL version — causes VDL errors)
- Direct PCL commands (printer ignores them)
- IPP Everywhere / driverless printing
