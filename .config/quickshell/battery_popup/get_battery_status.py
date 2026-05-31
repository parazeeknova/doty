#!/usr/bin/env python3
import json
import subprocess
from pathlib import Path

def read_sys_file(path: Path) -> str:
    try:
        return path.read_text().strip()
    except Exception:
        return ""

def main():
    config_dir = Path("/home/parazeeknova/.config/quickshell/battery_popup")
    history_file = config_dir / "history.json"
    bat_dir = Path("/sys/class/power_supply/BAT1")
    
    # Read raw attributes
    capacity_str = read_sys_file(bat_dir / "capacity")
    status = read_sys_file(bat_dir / "status") or "Unknown"
    charge_full_str = read_sys_file(bat_dir / "charge_full")
    charge_full_design_str = read_sys_file(bat_dir / "charge_full_design")
    charge_now_str = read_sys_file(bat_dir / "charge_now")
    current_now_str = read_sys_file(bat_dir / "current_now")
    voltage_now_str = read_sys_file(bat_dir / "voltage_now")
    
    # Defaults
    capacity = int(capacity_str) if capacity_str.isdigit() else 0
    charge_full = int(charge_full_str) if charge_full_str.isdigit() else 0
    charge_full_design = int(charge_full_design_str) if charge_full_design_str.isdigit() else 0
    charge_now = int(charge_now_str) if charge_now_str.isdigit() else 0
    current_now = int(current_now_str) if current_now_str.isdigit() else 0
    voltage_now = int(voltage_now_str) if voltage_now_str.isdigit() else 0
    
    # Calculate health
    health = 100.0
    if charge_full_design > 0:
        health = (charge_full / charge_full_design) * 100.0
    
    # Calculate power draw (W)
    power_draw_w = (voltage_now * current_now) / 1e12
    
    # Calculate remaining time
    time_remaining_str = "Unknown"
    if status == "Charging":
        if current_now > 0:
            rem_charge = charge_full - charge_now
            hours = rem_charge / current_now
            h = int(hours)
            m = int((hours - h) * 60)
            time_remaining_str = f"{h}h {m}m until full" if h > 0 else f"{m}m until full"
        else:
            time_remaining_str = "Not charging"
    elif status == "Discharging":
        if current_now > 0:
            hours = charge_now / current_now
            h = int(hours)
            m = int((hours - h) * 60)
            time_remaining_str = f"{h}h {m}m remaining" if h > 0 else f"{m}m remaining"
        else:
            time_remaining_str = "N/A"
    elif status == "Full":
        time_remaining_str = "Full"
    else:
        time_remaining_str = "N/A"
        
    # Get active profile
    active_profile = "Unknown"
    try:
        out = subprocess.check_output(["asusctl", "profile", "get"], text=True)
        for line in out.splitlines():
            if line.startswith("Active profile:"):
                active_profile = line.split(":")[-1].strip()
                break
    except Exception:
        pass

    # Read history & build sparkline
    history = []
    if history_file.exists():
        try:
            history = json.loads(history_file.read_text())
        except Exception:
            pass
    if not isinstance(history, list) or len(history) == 0:
        history = [0.0] * 10

    bars = ["▁", "▂", "▃", "▄", "▅", "▆", "▇", "█"]
    max_val = max(history) if len(history) > 0 else 0.0
    
    sparkline_chars = []
    for val in history:
        if max_val > 0.0:
            idx = int((val / max_val) * (len(bars) - 1))
            idx = max(0, min(idx, len(bars) - 1))
            sparkline_chars.append(bars[idx])
        else:
            sparkline_chars.append(bars[0])
            
    sparkline = "".join(sparkline_chars)

    result = {
        "capacity": capacity,
        "status": status,
        "health": round(health, 1),
        "power_draw_w": round(power_draw_w, 2),
        "time_remaining_str": time_remaining_str,
        "active_profile": active_profile,
        "sparkline": sparkline,
        "history": history
    }
    print(json.dumps(result))

if __name__ == "__main__":
    main()
