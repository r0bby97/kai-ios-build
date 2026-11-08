"""Capture only the offline library UI test, using the same non-parallel simulator.

This optional CI artifact records real controls without a production recording API
or personal user data. Recording failure must not change the test outcome.
"""
import signal
import subprocess
import sys
import time
from pathlib import Path

simulator_id, log_name, output_name = sys.argv[1:]
target_test = "testLibrarySettingsAndFirstConversation]"
output = Path(output_name)
output.parent.mkdir(parents=True, exist_ok=True)
log = Path(log_name)
log.touch(exist_ok=True)
running = True
recorder = None


def finish(*_):
    global running
    running = False


signal.signal(signal.SIGTERM, finish)
signal.signal(signal.SIGINT, finish)
with output.with_suffix(".log").open("w") as diagnostics, log.open() as stream:
    try:
        while running:
            line = stream.readline()
            if not line:
                time.sleep(0.1)
                continue
            if "Test Case" not in line or target_test not in line:
                continue
            if "started." in line and recorder is None:
                recorder = subprocess.Popen(
                    ["xcrun", "simctl", "io", simulator_id, "recordVideo", "--codec=h264", str(output)],
                    stdout=diagnostics, stderr=diagnostics,
                )
            elif "passed" in line or "failed" in line:
                break
    finally:
        if recorder is not None and recorder.poll() is None:
            recorder.send_signal(signal.SIGINT)
            try:
                recorder.wait(timeout=30)
            except subprocess.TimeoutExpired:
                recorder.kill()
                recorder.wait()
