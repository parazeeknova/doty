#!/usr/bin/env python3
import json
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
    
    # Read status and metrics
    status = read_sys_file(bat_dir / "status")
    current_now_str = read_sys_file(bat_dir / "current_now")
    voltage_now_str = read_sys_file(bat_dir / "voltage_now")
    
    current_now = int(current_now_str) if current_now_str.isdigit() else 0
    voltage_now = int(voltage_now_str) if voltage_now_str.isdigit() else 0
    
    # Calculate power draw (W) if discharging, else 0 for discharge rate
    power_draw = 0.0
    if status == "Discharging" and current_now > 0:
        power_draw = (voltage_now * current_now) / 1e12
        power_draw = round(power_draw, 2)
        
    # Load history
    history = []
    if history_file.exists():
        try:
            history = json.loads(history_file.read_text())
        except Exception:
            pass
            
    if not isinstance(history, list) or len(history) == 0:
        history = [0.0] * 10
        
    # Append and trim to last 10
    history.append(power_draw)
    if len(history) > 10:
        history = history[-10:]
        
    # Save
    config_dir.mkdir(parents=True, exist_ok=True)
    history_file.write_text(json.dumps(history))

if __name__ == "__main__":
    main()
