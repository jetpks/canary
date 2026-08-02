module Canary
  module Providers
    # A provider-agnostic completion: +text+ is the extracted assistant
    # text, +raw+ is the provider's full response flattened to a plain
    # Hash (no SDK objects) so it can be written to disk as-is.
    Sample = Struct.new(:text, :raw, keyword_init: true)
  end
end
