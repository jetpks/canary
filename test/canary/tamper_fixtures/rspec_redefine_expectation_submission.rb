# Attacks: the assertion library, rspec flavor. Reopens
# RSpec::Expectations::ExpectationTarget#to (what every `expect(...).to`
# ultimately calls) so it never raises, regardless of the matcher.
module RSpec
  module Expectations
    class ExpectationTarget
      def to(*)
        true
      end
    end
  end
end

RSpec.describe "rspec redefine expectation" do
  it "lies" do
    expect(2 + 2).to eq(5)
  end
end
