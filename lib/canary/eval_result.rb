module Canary
  # Structured outcome of a single `Pool#eval` call: stateless, one-shot -
  # every call is a fresh fork, with no session and no task context (unlike
  # RolloutResult, there is no grading here at all).
  #
  # +outcome+ is the eval taxonomy, distinct from RolloutResult#outcome's:
  # :ok (the child evaluated the code and reported, whatever it evaluated
  # to), :raised (the code raised a StandardError, caught and reported by
  # the child), :timeout (the parent gave up waiting and killed the child),
  # or :crash (the child died - signal, exit, exit! - without reporting at
  # all).
  #
  # +value+ and +exception+ are never the real evaluated object or the real
  # exception instance - the object itself never crosses the relay. Each is
  # reduced, in the child, to one of the bounded Data types below before the
  # Marshal write. +error+ is diagnostic text for the :timeout/:crash paths
  # only (mirrors RolloutResult#error) and, like RolloutResult#coverage, is
  # not part of the wire response - see Server#serialize_eval.
  EvalResult = Data.define(:outcome, :value, :stdout, :stderr, :exception, :error) do
    def initialize(outcome: :ok, value: nil, stdout: "", stderr: "", exception: nil, error: nil)
      super
    end

    def ok?
      outcome == :ok
    end

    def raised?
      outcome == :raised
    end

    def timeout?
      outcome == :timeout
    end

    def crash?
      outcome == :crash
    end
  end

  # Reopened (rather than assigned inside the Data.define block above) so
  # these two nest properly as EvalResult::Value/EvalResult::Raised -
  # constant assignment inside a `do...end` block follows its *lexical*
  # nesting, which is just Canary, not the anonymous class Data.define
  # returns; verified live, a `Value = ...` inside that block silently
  # became Canary::Value instead.
  class EvalResult
    # A bounded stand-in for an evaluated value: its class name and a
    # length-capped +inspect+, never the object itself. +class_name+ and
    # +inspect_text+ (rather than +class+/+inspect+) so this Data instance
    # keeps its own real #class and #inspect - Data.define(:class, :inspect)
    # would silently shadow both with the field values instead. Server#call
    # renames them to the wire's `class`/`inspect` keys at the JSON edge.
    Value = Data.define(:class_name, :inspect_text, :truncated)

    # A bounded stand-in for a raised exception: its class name and message,
    # never the exception object itself (and never a backtrace - the wire
    # carries none, so there is nothing from it left to sanitize).
    Raised = Data.define(:class_name, :message)
  end
end
