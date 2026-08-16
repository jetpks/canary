require "json"
require "fileutils"
require_relative "tool_loop"

module Canary
  # Runs +concurrency+ Canary::ToolLoop conversations concurrently, as
  # fibers in one Async reactor (BRIEF §2: fibers, never threads) - the
  # concurrent-bench driver behind bin/canary-loop-bench (BRIEF §7.6). Each
  # loop is an independent conversation bound to a task from +entries+
  # (round-robin), with its own transcript file under +out_dir+ -
  # Canary::ToolLoop itself is reused untouched, one instance per loop.
  #
  # The instrument is the summary this produces, not a live view into
  # ToolLoop's internals: rather than teach ToolLoop to expose per-turn data
  # to a caller, #call re-reads each loop's own transcript once ToolLoop has
  # finished writing it (JSON at the file edge, the house idiom already set
  # by ToolLoop::ModelTurnEntry/ToolResultEntry) and builds the "turns" rows
  # from the model_turn entries there.
  class LoopBench
    DEFAULT_TASK = "struct_vector"

    LoopSpec = Data.define(:loop_id, :entry, :transcript_path)
    private_constant :LoopSpec

    LoopRun = Data.define(:loop_id, :entry, :outcome, :started_at, :finished_at, :transcript_path)
    private_constant :LoopRun

    def initialize(chat_provider:, canary_client:, model:, entries:, concurrency:, out_dir:, max_turns: ToolLoop::DEFAULT_MAX_TURNS, tool_choice: "auto", max_tokens: Providers::OpenAICompat::DEFAULT_MAX_TOKENS)
      @chat_provider = chat_provider
      @canary_client = canary_client
      @model = model
      @entries = entries
      @concurrency = concurrency
      @out_dir = out_dir
      @max_turns = max_turns
      @tool_choice = tool_choice
      @max_tokens = max_tokens
    end

    # Runs the arm and writes out_dir/summary.json ({"loops" => [...]},
    # the pinned shape - BRIEF §7.6 decided decision 3). Returns the same
    # loops array so a caller doesn't have to re-parse the file it just
    # wrote.
    def call
      FileUtils.mkdir_p(@out_dir)
      specs = build_specs

      runs = Sync do
        specs.map { |spec| Async { run_loop(spec) } }.map(&:wait)
      end

      loops = runs.map { |run| loop_summary(run) }
      File.write(File.join(@out_dir, "summary.json"), JSON.generate({loops: loops}))
      loops
    end

    private

    def build_specs
      Array.new(@concurrency) do |i|
        loop_id = "loop-#{i}"
        entry = @entries[i % @entries.length]
        LoopSpec.new(loop_id: loop_id, entry: entry, transcript_path: File.join(@out_dir, "#{loop_id}.jsonl"))
      end
    end

    def run_loop(spec)
      File.delete(spec.transcript_path) if File.exist?(spec.transcript_path)
      loop_runner = ToolLoop.new(chat_provider: @chat_provider, canary_client: @canary_client, model: @model, transcript_path: spec.transcript_path, max_turns: @max_turns, tool_choice: @tool_choice, max_tokens: @max_tokens)

      started_at = monotonic
      outcome = loop_runner.call(spec.entry)
      finished_at = monotonic

      LoopRun.new(loop_id: spec.loop_id, entry: spec.entry, outcome: outcome, started_at: started_at, finished_at: finished_at, transcript_path: spec.transcript_path)
    end

    def loop_summary(run)
      {
        "loop_id" => run.loop_id,
        "task" => run.entry.name,
        "outcome" => run.outcome.to_s,
        "started_at" => run.started_at,
        "finished_at" => run.finished_at,
        "transcript" => File.basename(run.transcript_path),
        "turns" => turn_rows(run.transcript_path)
      }
    end

    def turn_rows(transcript_path)
      File.readlines(transcript_path)
        .map { |line| JSON.parse(line) }
        .select { |entry| entry["type"] == "model_turn" }
        .map { |entry| turn_row(entry) }
    end

    # +entry+'s response is either a ChatTurn's raw body verbatim (success -
    # top-level choices/usage) or ToolLoop#turn_payload's
    # {reason, message, raw} wrapper around a content Failure's own raw body
    # (also choices/usage, once unwrapped) - or, for a :transport_error, no
    # body at all (Providers::Error#raw is nil there, providers/error.rb's
    # own documented case). That last one has no wire finish_reason or usage
    # to report; the Failure's own reason string and 0 token counts are the
    # honest values, not a fabricated stand-in for data that was never sent.
    def turn_row(entry)
      response = entry["response"]
      body = response["raw"] || response
      choice = body["choices"] && body["choices"][0]
      usage = body["usage"] || {}

      {
        "finish_reason" => (choice && choice["finish_reason"]) || response["reason"].to_s,
        "prompt_tokens" => usage["prompt_tokens"] || 0,
        "completion_tokens" => usage["completion_tokens"] || 0,
        "elapsed_s" => entry["elapsed_s"]
      }
    end

    def monotonic
      Process.clock_gettime(Process::CLOCK_MONOTONIC)
    end
  end
end
