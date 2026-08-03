module Canary
  # A task pairs a solution (the file a model writes) with a test file (the
  # grader, which the solution does not contain) and the adapter that runs
  # them. A data shape only - Canary::Pool is what knows how to run one.
  Task = Data.define(:solution_path, :test_path, :adapter)
end
