$LOAD_PATH.unshift File.expand_path("../lib", __dir__)
require "canary"
require "minitest/autorun"

# Live-provider tests are OPT-IN, and the credential is only read when they
# are. Without CANARY_LIVE the suite reads no .env, holds no key and opens no
# socket - which is precisely what the frozen offline-sampler gate asserts, so
# that guarantee survives a real .env sitting in the working directory rather
# than being quietly hollowed out by it.
#
# Parsed by hand rather than through dotenv: the gemspec's runtime dependency
# set is asserted by a gate, and a test-only convenience has no business in the
# dependencies a consumer installs.
LIVE_ENV_FILE = File.expand_path("../.env", __dir__)

if ENV["CANARY_LIVE"] && File.exist?(LIVE_ENV_FILE)
  File.foreach(LIVE_ENV_FILE) do |line|
    next if line.lstrip.start_with?("#") || !line.include?("=")

    name, value = line.chomp.split("=", 2)
    # Never clobber a credential the caller set explicitly.
    ENV[name.strip] ||= value.strip.delete_prefix('"').delete_suffix('"')
  end
end
