module Canary
  module Providers
    # A typed provider failure. +reason+ is one of :budget_exhausted,
    # :spend_exceeded, :transport_error, :refusal, or :truncated - the
    # taxonomy Canary::Sampler and its callers switch on - plus whatever
    # honestly-named content-failure reasons a given provider adds for
    # outcomes Anthropic's own API never produces (Providers::OpenAICompat
    # adds :empty_completion and :unexpected_finish_reason); +message+ is
    # a human-readable detail for the on-disk record.
    #
    # +raw+ is the provider's full response flattened to a plain Hash, the
    # same shape Sample#raw carries, and is nil for the failures that have
    # no response to carry: the two guards Sampler raises before dispatch
    # (:budget_exhausted, :spend_exceeded) and :transport_error, where the
    # call never came back. The content outcomes (:refusal, :truncated) DO
    # have a well-formed response, and keeping it here is what lets the
    # record preserve a truncated answer's text instead of reducing it to a
    # reason code - see I14 F1.
    #
    # +text+ is the provider's visible completion text where the failure's
    # response actually carried one - first-class for the same reason
    # Sample#stop_reason went first-class in I19: a caller (Canary::Eval::
    # Runner) must never dig a provider-shaped key out of +raw+ to learn
    # whether a Failure still has gradable text underneath it. nil for
    # every guard/transport failure (no response at all) and for a content
    # failure whose response genuinely had nothing to show; non-nil for a
    # truncation or refusal whose response held recoverable prose - each
    # provider populates it from its own response shape.
    Error = Struct.new(:reason, :message, :raw, :text, keyword_init: true)
  end
end
