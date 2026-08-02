require_relative "../test_helper"
require "coverage"

# Proves, by running real code in real forked processes rather than by
# assertion-free narration, the load-bearing invariant behind the pool:
# Ruby compiles Coverage's hooks into the InstructionSequence at PARSE time.
# Only code parsed after Coverage.start/.setup is instrumented; executing
# already-parsed code after Coverage.start does not retroactively
# instrument it.
class CoverageOrderingTest < Minitest::Test
  TARGET = File.expand_path("fixtures/coverage_target.rb", __dir__)

  def test_parsing_before_coverage_start_yields_no_coverage_for_that_file
    reader, writer = IO.pipe

    pid = fork do
      reader.close
      require TARGET # parsed (and executed) BEFORE Coverage exists
      Coverage.start(lines: true)
      CoverageTarget.call # executing already-parsed code after start...
      result = Coverage.result
      Marshal.dump(result, writer)
      writer.close
      exit!(0)
    end
    writer.close
    result = Marshal.load(reader.read)
    reader.close
    Process.wait(pid)

    # ...does not retroactively instrument it: no entry for TARGET at all.
    refute_includes result.keys, TARGET,
      "expected no coverage entry for a file parsed before Coverage.start"
  end

  def test_parsing_after_coverage_start_yields_coverage_for_that_file
    reader, writer = IO.pipe

    pid = fork do
      reader.close
      Coverage.start(lines: true)
      load TARGET # parsed AFTER Coverage.start
      CoverageTarget.call
      result = Coverage.result
      Marshal.dump(result, writer)
      writer.close
      exit!(0)
    end
    writer.close
    result = Marshal.load(reader.read)
    reader.close
    Process.wait(pid)

    assert_includes result.keys, TARGET
    lines = result[TARGET][:lines]
    assert lines.compact.sum.positive?,
      "expected at least one executed, instrumented line in #{TARGET}"
  end
end
