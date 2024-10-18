SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"

# Change to the directory where the script is located.
cd "$SCRIPT_DIR"

# Check if AnvilID.txt exists
if [ ! -f AnvilID.txt ]; then
  echo "Error: AnvilID.txt does not exist."
  exit 1
fi

# Read the PID from AnvilID.txt
ANVIL_PID=$(cat AnvilID.txt)

# Check if AnvilID.txt is empty
if [ -z "$ANVIL_PID" ]; then
  echo "Error: AnvilID.txt is empty."
  exit 1
fi

# Check if the process is still running
if ps -p $ANVIL_PID > /dev/null; then
  # Stop the process with that PID
  kill -9 $ANVIL_PID
  if [ $? -eq 0 ]; then
    echo "Process with PID $ANVIL_PID has been stopped."
  else
    echo "Failed to stop process with PID $ANVIL_PID."
  fi
else
  echo "Error: No process with PID $ANVIL_PID is running."
fi
