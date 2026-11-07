# Legion fans

Uses nixpkgs' `lenovo-legion` package on the 81LB with BIOS 9VCN22WW.
The firmware controls fan speed. CPU cooling starts around 60 C and can stop
below 50 C. Stock RPM steps, GPU thresholds and the two highest points stay
unchanged.

`legion-fans.service` applies the preset at boot and reapplies it after resume.
Stopping it restores the stock curve. Both operations verify controller readback.

```sh
sudo systemctl stop legion-fans.service
```

The stock backup must exist at `/var/lib/legion-fans/9VCN22WW/stock.yaml`.
Do not overwrite it or reuse the preset after a BIOS change. First activation
requires reloading `legion_laptop` if it is still loaded read-only.

The driver's CPU/GPU temperature readings are unreliable on this BIOS.
Use `coretemp` and NVIDIA NVML instead.
