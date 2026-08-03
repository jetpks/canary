require "test_helper"

# Proves Canary::Eval::CompletionSink's one job: substitute the Fiber-local
# job index for whatever sample_index Canary::Sampler's own record_sink call
# supplies (always 0 here - see runner.rb and completion_sink.rb for why),
# so a completions artifact stays joinable to its Canary::Eval::Record on
# (task_name, model, sample_index, render_mode).
class CompletionSinkTest < Minitest::Test
  class SpySink
    attr_reader :calls

    def initialize
      @calls = []
    end

    def record(**kwargs)
      @calls << kwargs
    end
  end

  def test_substitutes_the_fiber_local_index_for_the_sinks_own
    spy = SpySink.new
    sink = Canary::Eval::CompletionSink.new(spy)

    Fiber[Canary::Eval::CompletionSink::SAMPLE_INDEX] = 2
    sink.record(model: "m", mode: :hidden, task_name: "t", sample_index: 0, prompt: "p", payload: {})

    assert_equal 2, spy.calls.first[:sample_index]
  ensure
    Fiber[Canary::Eval::CompletionSink::SAMPLE_INDEX] = nil
  end

  def test_falls_back_to_the_given_index_when_no_fiber_local_is_set
    spy = SpySink.new
    sink = Canary::Eval::CompletionSink.new(spy)

    sink.record(model: "m", mode: :hidden, task_name: "t", sample_index: 5, prompt: "p", payload: {})

    assert_equal 5, spy.calls.first[:sample_index]
  end
end
