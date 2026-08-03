module Canary
  module Eval
    # Canary::Sampler::RecordSink's own sample_index is Sampler's internal
    # per-call loop counter (Sampler#call's Array.new(n)), which is always 0
    # here: Runner asks the sampler for one completion at a time (n: 1) so
    # the concurrency lives in Runner's own Async::Semaphore fan-out, not
    # Sampler's sequential loop (see runner.rb). Left alone, every
    # completion for a given (task, model, render_mode) would land on disk
    # claiming sample_index 0, and only the k=1 record would ever be
    # joinable to one.
    #
    # Runner cannot pass its own job.index into Sampler#call - that
    # signature is frozen - so it hands it across via Fiber storage
    # instead: each job runs on its own fiber under the semaphore, so
    # Fiber[SAMPLE_INDEX] set at the top of one job's run never leaks into
    # a concurrently running job's. This sink reads that value and
    # substitutes it for Sampler's own sample_index before delegating, so a
    # completion on disk always carries the same sample_index as the
    # Record it produced.
    class CompletionSink
      SAMPLE_INDEX = :canary_eval_sample_index

      def initialize(sink)
        @sink = sink
      end

      def record(sample_index:, **rest)
        @sink.record(sample_index: Fiber[SAMPLE_INDEX] || sample_index, **rest)
      end
    end
  end
end
