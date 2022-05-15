# sh-gfs2-auto-mount

## About

A utility script and service to ensure gfs2 mounts get mounted on boot [With a target of Debian based systems].

This script checks that the necessary gfs2 perquisites are installed and configured and waits for `corosync` quorum, `dlm` startup, and `iscsi` device connection prior to in invoking a `gfs2`  mount. 

## Prerequisite

In order for this script to work you should have gfs2 installed and configured on your system

Notable actions include:

* Install and setup `open-iscsi` [*If `iscsi` is your backend*]
* Install and setup `corosync`
* Install and setup `dlm`
* Install and setup `gfs2-utils`
* Create a GFS2 partition
* Test and ensure you can mount a gfs2 partition manually

## Install GFS2 Auto Mount

copy or link `gfs2_auto_mount.sh` to `/usr/local/bin`

set permissions via ```chmod``` if needed

```bash
chmod 700 /usr/local/bin/gfs2_auto_mount.sh
```

You may also pick other locations and or permission configurations as desired. [optimal configurations here are still being evaluated]

## GFS2 Auto Mount Input Commands

| Command  | Description                                                  |
| -------- | ------------------------------------------------------------ |
| -d <arg> | The Input GFS2 Device.<br />Normally like `/dev/disk/by-path/ip-X.X.X.X:PORT-iscsi-iqn.YYYY-MM.DOMAIN.com:lun1-lun-1` |
| -m <arg> | The Output Folder to Mount. <br />Normally `/mnt/your_folder_mount` |
| -v       | Show Debug Output                                            |
| -u       | Note: Requires -m <arg>,<br />used by `ExecStop` to signal that the gfs2 mount should be unmounted if mounted on `systemctl stop` event |
| -h       | A Help Message                                               |

## Create GFS2 Auto Mount Service

I recommend using the name of the mount to conform to the `systemctl` standards.

For example, if your want to mount the iscsi mount `dev/sdc` to the `/mnt/iso` folder name your service `mnt-iso.service` and create it via:

```bash
nano /etc/systemd/system/mnt-iso.service
```

your service file should look like this

```bash
[Unit]
Description = Mount GFS2 share over iSCSI LUN For /mnt/iso
Wants=open-iscsi.service dlm.service corosync.service
After=open-iscsi.service dlm.service corosync.service

[Service]
Type=oneshot
RemainAfterExit=true
ExecStart=/bin/bash -c "/usr/local/bin/gfs2_auto_mount.sh -d /dev/disk/by-path/ip-X.X.X.X:PORT-iscsi-iqn.YYYY-MM.DOMAIN.com:lun1-lun-1 -m /mnt/iso -v"
ExecStop=/bin/bash -c "/usr/local/bin/gfs2_auto_mount.sh -m /mnt/iso -u -v"

[Install]
WantedBy=multi-user.target

```

Note: `Type=oneshot` and `Type=oneshot`can be replaced with `Type=forking` If desired.

Note: you can remove the `-d` from the `Exec` lines above to disable the debug output in `journalctl`

once saved reload `systemctl` via:

```bash
systemctl daemon-reload
```

Next test the service start via

```bash
systemctl start mnt-iso.service
```

Next check service status for errors, also check `journalctl` for service logs

```bash
systemctl status mnt-iso.service
journalctl -u mnt-iso.service -b
```

if the start test is good then test the stop service via:

```bash
systemctl stop mnt-iso.service
```

And check the `status` log for errors

Note: `dmesg` can be used to check for `gfs2` and `iscsi` errors

Note, you need to get a `gfs2` mount working manually before attempting to use this script, this script assume you have your `corosync`, `dlm`, and `gfs2` mount configured correctly

If both stop and start are working, enable the service

```bash
systemctl enable mnt-iso.service
```

and reboot.

On reboot check the service status, and review `systemctl` load dependencies via

```bash
systemctl list-dependencies
systemd-analyze critical-chain mnt-iso.service
```

For errors. Also check the mount via

```bash
lsblk
```

to ensure the mount is working.
