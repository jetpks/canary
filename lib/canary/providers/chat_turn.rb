module Canary
  module Providers
    # A provider-agnostic chat turn: +message+ is the assistant message
    # verbatim off the wire (role/content/tool_calls, replayed into the next
    # turn's messages array untouched - BRIEF §7.3, nothing here reshapes
    # what the model said), +tool_calls+ is the same call set again but as
    # typed ToolCall values (already parsed/validated, so a caller never
    # re-parses JSON off a raw hash), +finish_reason+ is a Symbol, and +raw+
    # is the same provider-agnostic full-response Hash Sample#raw carries.
    ChatTurn = Data.define(:message, :tool_calls, :finish_reason, :raw) do
      def initialize(tool_calls: [], **rest)
        super(tool_calls: tool_calls, **rest)
      end
    end

    # Reopened rather than assigned inside the Data.define block above, same
    # reason as Canary::EvalResult::Value/Raised (see eval_result.rb):
    # constant assignment inside a `do...end` block follows lexical nesting,
    # not the anonymous class Data.define returns.
    class ChatTurn
      # One validated tool call: +id+ and +name+ read straight off the
      # wire, +arguments+ already JSON-parsed to a Hash - BRIEF §6.3's
      # field-read gate means a ToolCall only ever exists once its
      # arguments have proven parseable.
      ToolCall = Data.define(:id, :name, :arguments)
    end
  end
end
