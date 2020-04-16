#!/usr/bin/env bash
## -- Start monitoring script

# Get current directory
CURRENT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# Source helpers and variables
source "$CURRENT_DIR/helpers.sh"
source "$CURRENT_DIR/variables.sh"

## Functions

# if user cancels
on_cancel()
{
  tmux display-message "Cancelling monitoring..."
  exit 0
}
trap 'on_cancel' TERM

# Check if verbose option is enabled
verbose_enabled() {
	local verbose_value="$(get_tmux_option "$verbose_option" "$verbose_default")"
	[ "$verbose_value" != "on" ]
}

## Main script

# get id of the current active pane
PANEID=$(tmux list-panes | grep "active" | awk -F\] '{print $3}' | awk '{print $1}')
PID_DIR=~/.tmux/notify

# write pid to file
echo "$$" > "$PID_DIR/$PANEID".pid

# Display tnotify start messsage
tmux display-message "Montoring pane..."

# Construct finish message
if verbose_enabled; then # If @tnotify-verbose is disabled
  complete_message="Tmux pane task completed!"
else # If @tnotify-verbose is enabled
  verbose_msg_value="$(get_tmux_option "$verbose_msg_option" "$verbose_msg_default")"
  complete_message=$(tmux display-message -p "$verbose_msg_value")
fi

# Check process status every 10 seconds
while true; do

  # capture pane output
  output=$(tmux capture-pane -pt $PANEID)

  # run tests to determine if work is done
  # if so, break and notify
  lc=$(echo $output | tail -c2)
  case $lc in
  "$" | "#" )
    tmux run-shell -b "$complete_message"
    cmd="
    printf '\ePtmux;\e\e[2t\e\\';
    sleep 0.1;
    printf '\ePtmux;\e\e[1t\e\\';
    "
    tmux split-window "$cmd"
    tmux split-window "echo -e \"\a\" && exit"
    break
  esac

  # Sleep for a given time
  monitor_sleep_duration_value=$(get_tmux_option "$monitor_sleep_duration" "$monitor_sleep_duration_default")
  sleep $monitor_sleep_duration_value
done

# job done - remove pid file
rm "$PID_DIR/$PANEID".pid
