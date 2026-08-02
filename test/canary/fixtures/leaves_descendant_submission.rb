# A submission that forks a background process and returns without waiting
# on or killing it - an ordinary output of an untrusted model (a shelled-out
# helper, a forked-and-forgotten reaper), not an exotic attack. It reports
# the descendant's pid via CANARY_DESCENDANT_PID_PATH so the test can prove
# the pool's process-group reap actually kills it, rather than merely
# returning. Used by pool_failure_test.rb.
descendant_pid = fork { sleep 60 }
File.write(ENV.fetch("CANARY_DESCENDANT_PID_PATH"), descendant_pid.to_s)
