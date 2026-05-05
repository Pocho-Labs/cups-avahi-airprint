# Pocho-Labs/cups-avahi-airprint

Fork of [chuckcharlie/cups-avahi-airprint](https://github.com/chuckcharlie/cups-avahi-airprint), which is itself a fork of [quadportnick/docker-cups-airprint](https://github.com/quadportnick/docker-cups-airprint).

### Supports ARM64 and AMD64.
Use the *latest* or *version#* tags to auto choose the right architecture.

This Alpine-based Docker image runs a CUPS instance that is meant as an AirPrint relay for printers that are already on the network but not AirPrint capable.

## Added in this fork

- **foo2zjs driver**: Adds support for HP LaserJet P1005, P1006, P1505, and other HP ZJS printers. Built from source at image build time.
- **Pre-configured cupsd.conf**: Ships a clean, complete `cupsd.conf` instead of patching the Alpine default with sed. Avoids duplicate/conflicting directives.
- **No-auth printing**: `AuthType None` on `<Location />` so print jobs are submitted without credentials. Admin interface still requires login via `AuthType Basic`.
- **Auto-retry on printer unavailable**: `ErrorPolicy retry-job` with 30s interval and up to 20 retries. Useful when the printer takes time to come online (e.g. powered on via smart plug or Home Assistant).
- **PR #49 fix**: Corrects the D-Bus PID file path (`dbus.pid`) and replaces the hardcoded `sleep 2` with a proper wait loop that checks for both D-Bus socket and Avahi PID before starting CUPS.

## How it works

CUPS registers shared printers directly with Avahi via D-Bus for mDNS/DNS-SD advertisement. When you add a printer in CUPS and mark it as shared, it automatically becomes discoverable by iPhones, iPads, and Macs on your network — no extra configuration needed.

## Changes in v2.0 (upstream)

- **Native DNS-SD registration**: CUPS now registers printers with Avahi directly over D-Bus, replacing the previous `airprint-generate.py` script. Fixes duplicate printer entries on iOS.
- **Removed `/services` volume**: No longer needed since Avahi service files are no longer generated externally.
- **Internal D-Bus daemon**: The container now runs its own `dbus-daemon` internally.

> **Upgrading from an earlier version? Remove `- /var/run/dbus:/var/run/dbus` from your compose file.** As of v2.0 the container runs its own D-Bus daemon. The bind mount will cause it to clobber the host's system D-Bus socket, breaking host services (systemd, smartd, NAS management UIs) until the container is removed.

## Configuration

### Volumes:
* `/config`: persistent printer configs (ppd files, printers.conf, cupsd.conf)

### Variables:
* `CUPSADMIN`: the CUPS admin user — default `cupsadmin`
* `CUPSPASSWORD`: the admin password — default same as `CUPSADMIN`
* `AVAHI_HOSTNAME`: the mDNS hostname Avahi will advertise — default `cups-airprint`. Set a unique name if running multiple instances or if the default conflicts with your NAS's own mDNS daemon.

### Ports/Network:
* Must run on host network. Required for multicast (AirPrint).

### Example docker compose:
```yaml
services:
  cups:
    image: pocholabs/cups-avahi-airprint:latest
    container_name: cups
    network_mode: host
    volumes:
      - ./config:/config
    environment:
      CUPSADMIN: "<YourAdminUsername>"
      CUPSPASSWORD: "<YourPassword>"
    restart: unless-stopped
```

### Build locally:
```bash
docker build -t cups-avahi-airprint .
```

## HP LaserJet P1005 setup

The HP LaserJet P1005 is a host-based (Winprinter) printer that requires the `foo2zjs`/`foo2hp` driver. This fork builds and installs it automatically.

1. Build or pull the image.
2. Open the CUPS web UI at `http://[host ip]:631`.
3. Add printer → select your HP LaserJet P1005 from the detected devices.
4. Choose driver: **HP LaserJet P1005 Foomatic/foo2hp**.
5. Mark the printer as **shared**.

The printer will appear in AirPrint on iOS and macOS automatically.

## Printing via network socket (AppSocket/JetDirect) with delayed power-on

If your printer is connected via AppSocket/JetDirect (`socket://`) and is powered on on-demand (e.g. via Home Assistant or a smart plug), make sure the device bridging the printer to the network (print server, router USB port, etc.) is fully connected **before** the printer finishes initializing.

With `ErrorPolicy retry-job`, CUPS retries every 30 seconds up to 20 times (10 minutes total) if the printer is temporarily unreachable. However, if the printer queue gets stopped by a hard backend failure, you can resume it manually:

```bash
docker exec <container> cupsenable <printer-name>
```

**Recommended power-on sequence when using Home Assistant:**
1. Turn on the print server / network device first
2. Wait ~30 seconds for it to establish its socket
3. Turn on the printer
4. CUPS will retry automatically until the printer responds

## Running on a NAS

First, make sure you've removed any `- /var/run/dbus:/var/run/dbus` bind mount (see upgrade note above).

NAS platforms (TrueNAS Scale, Synology, UGreen, QNAP, etc.) typically run their own `avahi-daemon` which can conflict with the container's in host network mode. Common symptoms:

* `bind() failed: Address in use` — host's Avahi owns UDP 5353, container falls back to IPv6 only.
* `Host name conflict, retrying with <hostname>-NN` loop in logs.
* Printers visible in CUPS web UI but not in AirPrint on iOS/macOS.

Things to try:

1. **Set `AVAHI_HOSTNAME`** to a unique value like `cups-airprint` (the default). Avoids the hostname-conflict loop.
2. **Disable the host's mDNS/Bonjour service.** On TrueNAS Scale: **Network → Global Configuration**. Trade-off: the NAS won't advertise over Bonjour (Time Machine, Finder hostname, etc.).
3. **Use a macvlan network** to give the container its own MAC/IP on your LAN. Avoids the port 5353 conflict entirely. Requires wired Ethernet; does not work over Wi-Fi or Docker Desktop.

## Add and set up a printer

* CUPS web UI: `http://[host ip]:631` — log in with CUPSADMIN/CUPSPASSWORD.
* Select **Share This Printer** when configuring the printer so it is advertised via AirPrint.

## Keeping in sync with upstream

This fork tracks [chuckcharlie/cups-avahi-airprint](https://github.com/chuckcharlie/cups-avahi-airprint) as the `upstream` remote:

```bash
# Add upstream (first time only)
git remote add upstream https://github.com/chuckcharlie/cups-avahi-airprint.git

# Review what upstream has that we don't
git fetch upstream
git log HEAD..upstream/master --oneline

# Merge upstream changes
git merge upstream/master
```
