module Canary
  # Structured outcome of a single rollout: per-example results plus
  # whatever Coverage.result data the child collected before exiting.
  #
  # +outcome+ is the terminal-outcome taxonomy: :ok (the child ran to
  # completion and reported, however its examples fared), :error (an
  # exception raised inside the adapter, caught and reported by the child),
  # :crash (the child died - signal, exit, exit! - without reporting at
  # all), :timeout (the parent gave up waiting and killed the child), or
  # :invalid (the child reported, but the grader files it ran under were
  # modified during the rollout - not scored, regardless of what it said).
  RolloutResult = Struct.new(
    :adapter, :examples, :passed, :failed, :total, :coverage, :error, :outcome,
    keyword_init: true
  ) do
    def initialize(*)
      super
      self.outcome ||= :ok
    end

    def success?
      outcome == :ok && error.nil? && failed.zero?
    end

    def ok?
      outcome == :ok
    end

    def error?
      outcome == :error
    end

    def crash?
      outcome == :crash
    end

    def timeout?
      outcome == :timeout
    end

    def invalid?
      outcome == :invalid
    end
  end

  # A single test/example outcome, framework-agnostic.
  ExampleResult = Struct.new(:name, :status, :message, keyword_init: true)
end
