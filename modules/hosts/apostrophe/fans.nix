{ self, ... }: {
  flake.nixosModules.apostropheFans =
    { pkgs, ... }:
    {
      # -- Aggressive Fan Curve for CPU & GPU (sysfs hardware control) --
      systemd.services.fan-control = {
        description = "ASUS custom aggressive fan curve";
        after = [ "asusd.service" ];
        wantedBy = [ "multi-user.target" ];
        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
          ExecStart = pkgs.writeShellScript "apply-fan-curve" ''
            HW=""
            for dev in /sys/class/hwmon/hwmon*; do
              if [ -f "$dev/name" ] && [ "$(cat "$dev/name")" = "asus_custom_fan_curve" ]; then
                HW="$dev"
                break
              fi
            done

            if [ -z "$HW" ]; then
              echo "Error: asus_custom_fan_curve hwmon device not found!" >&2
              exit 1
            fi

            echo "Applying aggressive fan curve to $HW..."

            echo 2 > "$HW/pwm1_enable"
            echo 2 > "$HW/pwm2_enable"

            # CPU fan curve: temp°C -> pwm(0-255)
            echo 35 > "$HW/pwm1_auto_point1_temp"; echo 40  > "$HW/pwm1_auto_point1_pwm"
            echo 45 > "$HW/pwm1_auto_point2_temp"; echo 70  > "$HW/pwm1_auto_point2_pwm"
            echo 55 > "$HW/pwm1_auto_point3_temp"; echo 100 > "$HW/pwm1_auto_point3_pwm"
            echo 62 > "$HW/pwm1_auto_point4_temp"; echo 140 > "$HW/pwm1_auto_point4_pwm"
            echo 68 > "$HW/pwm1_auto_point5_temp"; echo 175 > "$HW/pwm1_auto_point5_pwm"
            echo 74 > "$HW/pwm1_auto_point6_temp"; echo 210 > "$HW/pwm1_auto_point6_pwm"
            echo 80 > "$HW/pwm1_auto_point7_temp"; echo 240 > "$HW/pwm1_auto_point7_pwm"
            echo 85 > "$HW/pwm1_auto_point8_temp"; echo 255 > "$HW/pwm1_auto_point8_pwm"

            # GPU fan curve (more aggressive)
            echo 35 > "$HW/pwm2_auto_point1_temp"; echo 45  > "$HW/pwm2_auto_point1_pwm"
            echo 45 > "$HW/pwm2_auto_point2_temp"; echo 80  > "$HW/pwm2_auto_point2_pwm"
            echo 55 > "$HW/pwm2_auto_point3_temp"; echo 120 > "$HW/pwm2_auto_point3_pwm"
            echo 62 > "$HW/pwm2_auto_point4_temp"; echo 160 > "$HW/pwm2_auto_point4_pwm"
            echo 68 > "$HW/pwm2_auto_point5_temp"; echo 200 > "$HW/pwm2_auto_point5_pwm"
            echo 74 > "$HW/pwm2_auto_point6_temp"; echo 230 > "$HW/pwm2_auto_point6_pwm"
            echo 80 > "$HW/pwm2_auto_point7_temp"; echo 250 > "$HW/pwm2_auto_point7_pwm"
            echo 85 > "$HW/pwm2_auto_point8_temp"; echo 255 > "$HW/pwm2_auto_point8_pwm"

            echo "Custom aggressive fan curve applied successfully."
          '';
        };
      };

      powerManagement.resumeCommands = ''
        HW=""
        for dev in /sys/class/hwmon/hwmon*; do
          if [ -f "$dev/name" ] && [ "$(cat "$dev/name")" = "asus_custom_fan_curve" ]; then
            HW="$dev"
            break
          fi
        done

        if [ -n "$HW" ]; then
          echo "Applying aggressive fan curve on resume to $HW..."

          echo 2 > "$HW/pwm1_enable"
          echo 2 > "$HW/pwm2_enable"

          # CPU fan curve: temp°C -> pwm(0-255)
          echo 35 > "$HW/pwm1_auto_point1_temp"; echo 40  > "$HW/pwm1_auto_point1_pwm"
          echo 45 > "$HW/pwm1_auto_point2_temp"; echo 70  > "$HW/pwm1_auto_point2_pwm"
          echo 55 > "$HW/pwm1_auto_point3_temp"; echo 100 > "$HW/pwm1_auto_point3_pwm"
          echo 62 > "$HW/pwm1_auto_point4_temp"; echo 140 > "$HW/pwm1_auto_point4_pwm"
          echo 68 > "$HW/pwm1_auto_point5_temp"; echo 175 > "$HW/pwm1_auto_point5_pwm"
          echo 74 > "$HW/pwm1_auto_point6_temp"; echo 210 > "$HW/pwm1_auto_point6_pwm"
          echo 80 > "$HW/pwm1_auto_point7_temp"; echo 240 > "$HW/pwm1_auto_point7_pwm"
          echo 85 > "$HW/pwm1_auto_point8_temp"; echo 255 > "$HW/pwm1_auto_point8_pwm"

          # GPU fan curve (more aggressive)
          echo 35 > "$HW/pwm2_auto_point1_temp"; echo 45  > "$HW/pwm2_auto_point1_pwm"
          echo 45 > "$HW/pwm2_auto_point2_temp"; echo 80  > "$HW/pwm2_auto_point2_pwm"
          echo 55 > "$HW/pwm2_auto_point3_temp"; echo 120 > "$HW/pwm2_auto_point3_pwm"
          echo 62 > "$HW/pwm2_auto_point4_temp"; echo 160 > "$HW/pwm2_auto_point4_pwm"
          echo 68 > "$HW/pwm2_auto_point5_temp"; echo 200 > "$HW/pwm2_auto_point5_pwm"
          echo 74 > "$HW/pwm2_auto_point6_temp"; echo 230 > "$HW/pwm2_auto_point6_pwm"
          echo 80 > "$HW/pwm2_auto_point7_temp"; echo 250 > "$HW/pwm2_auto_point7_pwm"
          echo 85 > "$HW/pwm2_auto_point8_temp"; echo 255 > "$HW/pwm2_auto_point8_pwm"

          echo "Custom aggressive fan curve applied on resume."
        else
          echo "Error: asus_custom_fan_curve hwmon device not found on resume!" >&2
        fi
      '';
    };
}
