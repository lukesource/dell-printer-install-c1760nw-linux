# Dell C1760nw on Linux

Automated installer for the Dell C1760nw color laser printer on Ubuntu/Debian.

If you've landed here after hours of trying Samsung CLP-365 drivers, foo2qpdl, or IPP Everywhere — you're in the right place.

## The Short Version

The Dell C1760nw is a **rebranded Xerox Phaser 6000B**. It speaks **HBPLv1** (Host-Based Printer Language, version 1) over a raw TCP socket on port 9100. It does not speak PostScript, PCL, IPP, Samsung SPL-C, QPDL, or HBPLv2. None of those will work, no matter how you configure them.

The correct driver is `foo2hbpl1` from the [mikerr/foo2zjs](https://github.com/mikerr/foo2zjs) fork. It is not in the standard Ubuntu/Debian repos and must be compiled from source.

## Requirements

- Ubuntu 22.04+ or Debian 12+ (may work on others)
- CUPS installed and running
- Printer connected to your network
- `sudo` access

## Install

```bash
git clone https://github.com/lukesource/dell-printer-install-c1760nw-linux.git
cd dell-printer-install-c1760nw-linux
sudo ./install-dell-c1760nw.sh                # uses default IP 192.168.4.30
sudo ./install-dell-c1760nw.sh 192.168.1.50   # or specify your printer's IP
```

The script will:
1. Install build dependencies (`libjbig-dev`, `ghostscript`, etc.)
2. Clone and compile `foo2hbpl1` from source
3. Patch a bug in the upstream wrapper script that breaks color printing
4. Install color management (CRD/CMS) files
5. Create and enable a CUPS queue named `DellC1760nw`

## Print

```bash
lp -d DellC1760nw file.pdf                       # monochrome (default)
lp -d DellC1760nw -o ColorMode=Color file.pdf    # color
echo 'Hello' | lp -d DellC1760nw                 # quick test
lpstat -p DellC1760nw                             # check status
```

## What Does NOT Work

Don't waste time on these — they all fail silently or cancel immediately:

| Driver / Method | Why it fails |
|---|---|
| foo2qpdl / Samsung CLP-365 PPD | Wrong protocol (QPDL ≠ HBPL) |
| foo2hbpl2 / Dell C1765 PPD | Wrong HBPL version (v2 ≠ v1) |
| IPP Everywhere / driverless | Printer doesn't support IPP |
| Samsung SPL-C / rastertospl | Wrong protocol entirely |
| Direct PCL/PostScript | Printer ignores it |

The printer will appear to accept jobs and return "Ready" but never print a page.

## Troubleshooting

**Printer not reachable:**
```bash
timeout 3 bash -c "echo > /dev/tcp/192.168.4.30/9100" && echo OK
```

**Job completes but nothing prints:**
```bash
sudo grep "Job" /var/log/cups/error_log | tail -20
```

**Test the filter pipeline directly:**
```bash
echo '%!PS' | foo2hbpl1-wrapper -c 2>&1 | head -c 100
# Should output binary data starting with ESC%-12345X
# If you see a Ghostscript error, the wrapper patch may not have applied
```

**CUPS not running:**
```bash
sudo systemctl enable --now cups
```

## Technical Details

- **Protocol**: HBPLv1 over JetDirect (raw TCP port 9100)
- **Driver binary**: `foo2hbpl1` (compiled from [mikerr/foo2zjs](https://github.com/mikerr/foo2zjs))
- **PPD**: `Dell-C1760.ppd` from the same repo
- **Filter chain**: CUPS → foomatic-rip → foo2hbpl1-wrapper → Ghostscript → foo2hbpl1 → socket
- **Known upstream bug**: `foo2hbpl1-wrapper` references an undefined `$SCREEN` variable, causing Ghostscript to try loading a directory as a PostScript file. The install script patches this with `sed`.
- **Build dep**: `libjbig-dev` (JBIG1 compression, required to compile `foo2hbpl1`)
