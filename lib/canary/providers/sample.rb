module Canary
  module Providers
    # A provider-agnostic completion: +text+ is the extracted assistant
    # text, +raw+ is the provider's full response flattened to a plain
    # Hash (no SDK objects) so it can be written to disk as-is, and
    # +stop_reason+ is the provider's own termination signal (a Symbol) -
    # first-class so callers never have to dig a provider-shaped key out
    # of +raw+ to learn how a completion ended.
    Sample = Struct.new(:text, :raw, :stop_reason, keyword_init: true)
  end
end
