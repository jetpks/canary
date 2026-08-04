# A submission that kills its own process with a fatal signal, standing in
# for a segfault or similar abnormal termination. Used by
# pool_failure_test.rb.
Process.kill("KILL", Process.pid)
