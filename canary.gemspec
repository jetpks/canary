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
  #
  # tasks/** is packaged for the same reason: Canary::TaskRepo::ROOT is also
  # gem-relative (../../tasks from lib/canary/task_repo.rb), so the corpus
  # must ship for TaskRepo.all's default root to resolve in an installed gem
  # instead of dangling the way .rubocop.yml once did (I07 D2).
  spec.files         = Dir["lib/**/*.rb"] + [".rubocop.yml"] + Dir["tasks/**/*"].select { |f| File.file?(f) }
  spec.require_paths = ["lib"]

  spec.add_dependency "anthropic", "~> 1.59"
  spec.add_dependency "async", "~> 2.43"
  spec.add_dependency "dry-monads", "~> 1.10"
  spec.add_dependency "minitest", "~> 6.0"
  spec.add_dependency "rspec-core", "~> 3.13"
  spec.add_dependency "rspec-expectations", "~> 3.13"
  spec.add_dependency "rspec-mocks", "~> 3.13"
  spec.add_dependency "rubocop", "~> 1.88"

  # base64 stopped shipping as a Ruby default gem as of 3.4 (we're on 4.0);
  # the installed anthropic-1.59.0 gem's lib/anthropic.rb still `require
  # "base64"`s unconditionally without declaring it as a dependency of its
  # own gemspec, so it has to be supplied here or `require "canary"` raises
  # LoadError the moment providers/anthropic.rb loads the gem.
  spec.add_development_dependency "base64"
  spec.add_development_dependency "rake", "~> 13.0"
end
