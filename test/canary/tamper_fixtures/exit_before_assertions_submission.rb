# Attacks: the failure taxonomy's boundary case. Calls exit before defining
# or running anything, so no assertion ever executes. Unlike the forging
# vectors above, this can't fake a pass - `exit` (not exit!) unwinds out of
# run_in_child before the real Marshal.dump ever runs, so the child reports
# nothing and the pool correctly calls it a crash.
exit
