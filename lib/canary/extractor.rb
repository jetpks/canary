require "prism"

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

    # Outcomes the eval runner treats as a gradable submission. :ok is the
    # fenced answer the contract asks for; :bare_ruby is the unfenced one it
    # accepts anyway (see .bare_ruby?). Named here rather than compared
    # inline so the runner has one place to ask, and adding a third shape is
    # a data change here rather than a condition edited there.
    ACCEPTED = %i[ok bare_ruby bare_malformed].freeze

    def self.call(text)
      new(text).call
    end

    def initialize(text)
      @text = text
    end

    def call
      segment = ruby_segment
      return Result.new(code: body_of(segment), outcome: :ok) if segment
      return Result.new(code: bare_text, outcome: bare_outcome) if submitted_bare?

      Result.new(code: nil, outcome: refusal_outcome)
    end

    private

    def bare_text
      @text.strip
    end

    # A response carrying NO fence anywhere that parses as Ruby on its own is
    # taken as the submission rather than refused.
    #
    # Prompt's own note says the fence requirement made part of a hidden-arm
    # score "whether a model happened to guess this harness's convention,"
    # biased against the weaker models the corpus exists to discriminate
    # among. Stating the contract (schema 3) was the first half of that fix;
    # this is the second. Measured 2026-09-01: nemotron-3-super lost 83 of
    # 132 samples to :no_fenced_code, and re-checking the committed
    # completions.jsonl offline showed 82 of those 83 were bare, valid Ruby -
    # the model was failing the packaging, not the task.
    #
    # Deliberately narrow in three ways:
    #   - only when NO fence exists. A response that fenced something tagged
    #     for another language made a choice, and :no_ruby_fence stays the
    #     honest reading of it.
    #   - Prism (in-process, same parser Prefilter's tier 0 uses), not a
    #     shell-out, and not a heuristic on "looks like code."
    #   - it must DEFINE something. Parsing alone is far too weak a test:
    #     prose is routinely valid Ruby, because bare words chain into method
    #     calls. "no fenced code here at all" parses clean, and so does "OK"
    #     (a constant lookup) and "I cannot help with that request". Requiring
    #     a def, class or module node is what separates a submission from a
    #     sentence, and it costs nothing: of the 82 bare-Ruby nemotron samples
    #     this rule was built from, 82 also define something.
    #
    # Empty falls out of the same requirement rather than needing its own
    # guard - Prism parses "" happily as an empty program, and an empty
    # program defines nothing.
    # An unfenced, non-empty answer is a SUBMISSION. Whether it is good Ruby is
    # the verifier's question, not the extractor's.
    #
    # Only emptiness refuses here. Anything else the model wrote where an
    # answer belongs gets handed to the prefilter, which is already the path a
    # FENCED answer that doesn't parse takes: Prefilter tier 0 finds the parse
    # error, Verifier returns passed: false, and the runner records
    # scored: true - "the model's own code falling short". Excusing the
    # unfenced case was an asymmetry, not a policy: it let a model that wrote
    # broken Ruby without a fence drop out of the denominator entirely, while
    # the same broken Ruby inside a fence counted against it.
    #
    # Measured 2026-09-01: olmo-3-7b lost 56 of 132 samples to this, writing
    # things like "if other respond_to? :to_h" - a missing dot, plainly an
    # attempt at the task, scored as though it had never answered. That
    # flattered its rate, since refusals leave the denominator.
    #
    # Truncation is still NOT a failure: verified_record defers to
    # Prefilter::Report#truncated, so a generation cut off mid-construct
    # remains a non-score (:truncated) rather than being blamed on the model.
    def submitted_bare?
      !@text.include?(FENCE) && !bare_text.empty?
    end

    # Both are graded; the label preserves which shape arrived, so a later
    # reader can separate "wrote clean Ruby, just no fence" from "wrote
    # something that isn't valid Ruby at all" without re-parsing the corpus.
    def bare_outcome
      result = Prism.parse(bare_text)
      return :bare_malformed unless result.success?

      result.value.breadth_first_search { |node| definition?(node) } ? :bare_ruby : :bare_malformed
    end

    def definition?(node)
      node.is_a?(Prism::DefNode) || node.is_a?(Prism::ClassNode) || node.is_a?(Prism::ModuleNode)
    end

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
