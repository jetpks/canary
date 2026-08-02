module Canary
  module Providers
    # A typed provider failure. +reason+ is one of :budget_exhausted,
    # :transport_error, or :refusal - the taxonomy Canary::Sampler and its
    # callers switch on; +message+ is a human-readable detail for the
    # on-disk record.
    Error = Struct.new(:reason, :message, keyword_init: true)
  end
end
