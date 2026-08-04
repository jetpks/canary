# Attacks: the grader-digest check itself, by deleting the grader outright
# rather than rewriting it. Pool#rollout_task digests test_path before
# forking and again after the child exits; Digest::SHA256.file raises
# Errno::ENOENT when the file is simply gone. Deletion is the most direct
# way a solution can "modify" its own grader, and crashing the harness on a
# missing file would be worse than mis-scoring the rollout. tamper_test.rb
# passes the scratch grader's path via CANARY_TAMPER_GRADER_PATH (a fresh
# Tempfile per run, so this never touches a checked-in fixture).
File.delete(ENV.fetch("CANARY_TAMPER_GRADER_PATH"))
