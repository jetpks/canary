module Canary
  module Providers
    # A typed provider failure. +reason+ is one of :budget_exhausted,
    # :spend_exceeded, :transport_error, :refusal, or :truncated - the
    # taxonomy Canary::Sampler and its callers switch on; +message+ is a
    # human-readable detail for the on-disk record.
    #
    # +raw+ is the provider's full response flattened to a plain Hash, the
    # same shape Sample#raw carries, and is nil for the failures that have
    # no response to carry: the two guards Sampler raises before dispatch
    # (:budget_exhausted, :spend_exceeded) and :transport_error, where the
    # call never came back. The content outcomes (:refusal, :truncated) DO
    # have a well-formed response, and keeping it here is what lets the
    # record preserve a truncated answer's text instead of reducing it to a
    # reason code - see I14 F1.
    Error = Struct.new(:reason, :message, :raw, keyword_init: true)
  end
end
