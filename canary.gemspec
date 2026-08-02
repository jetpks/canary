require_relative "lib/canary/version"

Gem::Specification.new do |spec|
  spec.name          = "canary"
  spec.version       = Canary::VERSION
  spec.authors       = ["eric jacobs"]
  spec.email         = ["eric@ebj.dev"]
  spec.summary       = "A Ruby coding evaluation and RL environment."
  spec.description   = "A Ruby coding evaluation and RL environment. Ruby as a tail-generalization canary."
  spec.homepage      = "https://github.com/jetpks/canary"
  spec.license       = "MIT"
  spec.required_ruby_version = ">= 4.0.0"

  # .rubocop.yml is packaged alongside lib/ (not just under lib/**/*.rb)
  # because Canary::Prefilter::CONFIG_PATH resolves it relative to the
  # installed gem root - without this it dangles in an installed gem.
  spec.files         = Dir["lib/**/*.rb"] + [".rubocop.yml"]
  spec.require_paths = ["lib"]

  spec.add_dependency "async", "~> 2.43"
  spec.add_dependency "minitest", "~> 6.0"
  spec.add_dependency "rspec-core", "~> 3.13"
  spec.add_dependency "rspec-expectations", "~> 3.13"
  spec.add_dependency "rspec-mocks", "~> 3.13"
  spec.add_dependency "rubocop", "~> 1.88"

  spec.add_development_dependency "rake", "~> 13.0"
end
