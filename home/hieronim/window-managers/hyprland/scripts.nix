{ pkgs, ... }:
{
  suspendScript = pkgs.writeShellScript "script" ''
    # check if any player has status "Playing"
    ${pkgs.lib.getExe pkgs.playerctl} -a status | ${pkgs.lib.getExe pkgs.ripgrep} Playing -q
    # only suspend if nothing is playing
    if [ $? == 1 ]; then
      ${pkgs.systemd}/bin/systemctl suspend
    fi
  '';

  rofiPowerMenuScript = pkgs.writeShellScript "script" ''
    # Icons and options
    lock="🔒️  Lock"
    logout="🏃  Log Out"
    shutdown="💡  Shut Down"
    reboot="🔃  Reboot"
    sleep="💤  Sleep"
    # Get answer from user via rofi
    selected_option=$(echo "$lock
    $logout
    $sleep
    $reboot
    $shutdown" | ${pkgs.rofi-wayland}/bin/rofi -dmenu -i -p "Power" -theme-str 'listview { lines: 5; fixed-height: true; } mainbox { children: [ listview ]; }')
    # Do something based on selected option
    if [ "$selected_option" == "$lock" batter]
    then
      hyprlock
    elif [ "$selected_option" == "$logout" ]
    then
      loginctl terminate-user "$(whoami)"
    elif [ "$selected_option" == "$shutdown" ]
    then
      systemctl poweroff
    elif [ "$selected_option" == "$reboot" ]
    then
      systemctl reboot
    elif [ "$selected_option" == "$sleep" ]
    then
      systemctl suspend
    else
      echo "No match"
    fi
  '';
}
