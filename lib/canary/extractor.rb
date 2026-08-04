module Canary
  # Turns a model's markdown answer into the one Ruby file the verifier
  # runs. A response is prose with fenced code blocks, not a source file -
  # this pulls out the fence most likely to be the model's actual answer
  # and, when none qualifies, says so through +outcome+ rather than handing
  # back prose as if it were code.
  #
  # Splitting the whole text on the fence delimiter turns "closed block" and
  # "block truncated mid-generation" into the same lookup: every odd-indexed
  # segment is fence-interior content, in document order, whether or not the
  # final one ever saw a closing marker. The first such segment tagged ruby
  # (or left untagged) wins - real responses pair a definition block with a
  # shorter usage-example block, and the definition comes first (verified
  # against all four real fixtures in extractor_test.rb; picking the longest
  # block instead picks the usage example on claude-haiku-4-5-20251001).
  class Extractor
    Result = Data.define(:code, :outcome)

    FENCE = "```"
    RUBY_TAGS = ["", "ruby"].freeze

    def self.call(text)
      new(text).call
    end

    def initialize(text)
      @text = text
    end

    def call
      segment = ruby_segment
      return Result.new(code: nil, outcome: refusal_outcome) unless segment

      Result.new(code: body_of(segment), outcome: :ok)
    end

    private

    def ruby_segment
      fenced_segments.find { |segment| ruby_tag?(tag_of(segment)) }
    end

    # Odd indices are fence-interior: text.split(FENCE) alternates
    # outside/inside starting outside, so index 1, 3, 5... are always
    # inside a fence - including the last one when the fence never closed,
    # which is exactly the shape a max_tokens cutoff mid-block leaves. That
    # segment is handed off like any other rather than refused: an opening
    # fence is still a real "code starts here" signal, and Prefilter's own
    # truncation detection (parse error anchored at EOF) already exists to
    # classify what's inside it - refusing here would keep truncated-but-
    # real code from ever reaching that check.
    def fenced_segments
      @text.split(FENCE, -1).select.with_index { |_, i| i.odd? }
    end

    def tag_of(segment)
      segment[/\A[^\n]*/].strip.downcase
    end

    def body_of(segment)
      segment.sub(/\A[^\n]*\n?/, "").strip
    end

    def ruby_tag?(tag)
      RUBY_TAGS.include?(tag)
    end

    # Distinct refusals so the eval runner can tell "the model never fenced
    # an answer" apart from "the model fenced something, just not Ruby" -
    # collapsing them would make a refusal indistinguishable from the kind
    # of bad-code failure a real, badly-tagged answer produces.
    def refusal_outcome
      @text.include?(FENCE) ? :no_ruby_fence : :no_fenced_code
    end
  end
end
