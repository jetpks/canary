require "test_helper"
require "tempfile"

# I15 published pass rates that were not model capability: the prefilter
# rejected a correct reference solution (shadowed_constant_circle, on a
# style-shaped Lint cop) before a rollout ever ran. Fixing that cop is a
# symptom fix; this is the class-wide guard - a dynamic assertion, over
# whatever Canary::TaskRepo.all resolves right now, that the WHOLE verifier
# path (not just the grader) accepts every reference solution in the corpus.
# The next prefilter change that renders a correct solution unscoreable
# fails here, loudly, before it costs a task its pass rate.
class CorpusInvariantsTest < Minitest::Test
  def test_every_reference_solution_in_the_corpus_satisfies_the_verifier
    verifier = Canary::Verifier.new

    Canary::TaskRepo.all.each do |entry|
      result = verifier.call(entry.reference)

      assert result.passed, "#{entry.name}: expected the verifier to accept the reference solution, " \
        "got prefilter_clean=#{result.prefilter_report.clean?} " \
        "findings=#{result.prefilter_report.findings.map(&:type)} " \
        "rollout=#{result.rollout_result&.success?}"
    end
  end

  # I16/I17 F1: the prefilter folded parse.warnings in with parse.errors, so
  # a submission Prism itself parsed fine still hard-rejected the rollout.
  # This is the guard that would have caught it directly - append a
  # semantics-preserving unused local (provokes Prism's
  # :unused_local_variable warning; asserted explicitly below so this goes
  # loud, not vacuous, if the injection ever stops provoking one) to every
  # reference solution in the corpus, and require that variant to still
  # register as a Prism warning AND still reach and pass the rollout.
  def test_every_reference_solution_survives_a_warning_only_variant
    verifier = Canary::Verifier.new

    Canary::TaskRepo.all.each do |entry|
      Tempfile.create(["canary_warning_variant_", ".rb"]) do |file|
        file.write("#{File.read(entry.reference.solution_path)}\ncanary_warning_probe = 1\n")
        file.flush

        result = verifier.call(warning_variant_task(entry, file.path))

        assert result.prefilter_report.syntax_valid, "#{entry.name}: expected the warning-injected variant to still parse"
        assert result.prefilter_report.findings.any? { |f| f.tier == 0 && f.type == :unused_local_variable },
          "#{entry.name}: expected the injected unused local to register as a tier-0 warning finding, " \
          "got findings=#{result.prefilter_report.findings.map(&:type)}"
        refute_nil result.rollout_result, "#{entry.name}: expected the warning-injected variant to reach the rollout"
        assert result.passed, "#{entry.name}: expected the warning-injected variant to pass, " \
          "got prefilter_clean=#{result.prefilter_report.clean?} rollout=#{result.rollout_result&.success?}"
      end
    end
  end

  private

  def warning_variant_task(entry, solution_path)
    Canary::Task.new(solution_path: solution_path, test_path: entry.reference.test_path, adapter: entry.reference.adapter)
  end
end
