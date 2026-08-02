# Attacks: Canary::RolloutResult, driven through the rspec adapter rather
# than minitest, to check the forgery in forge_rollout_result_new_submission
# is adapter-independent - the forgery happens in run_in_child, above both
# adapters, so it should be. Same technique, different adapter, as a parity
# check rather than a new mechanism.
class Canary::RolloutResult
  class << self
    alias_method :real_new, :new

    def new(**)
      real_new(adapter: :rspec, examples: [], passed: 999, failed: 0, total: 999)
    end
  end
end

RSpec.describe "rspec forge rollout result" do
  it "actually fails" do
    expect(2 + 2).to eq(5)
  end
end
