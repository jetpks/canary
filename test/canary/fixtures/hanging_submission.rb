# A submission that never terminates. Used by pool_failure_test.rb to prove
# the pool's own timeout bounds a rollout instead of blocking the parent
# forever.
sleep 60
