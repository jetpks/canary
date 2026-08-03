require "test_helper"

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
end
