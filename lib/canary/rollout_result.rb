module Canary
  # Structured outcome of a single rollout: per-example results plus
  # whatever Coverage.result data the child collected before exiting.
  RolloutResult = Struct.new(
    :adapter, :examples, :passed, :failed, :total, :coverage, :error,
    keyword_init: true
  ) do
    def success?
      error.nil? && failed.zero?
    end
  end

  # A single test/example outcome, framework-agnostic.
  ExampleResult = Struct.new(:name, :status, :message, keyword_init: true)
end
