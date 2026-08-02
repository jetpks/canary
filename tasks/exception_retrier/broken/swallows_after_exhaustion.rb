class TransientError < StandardError; end
class PermanentError < StandardError; end

class Retrier
  def self.call(max_attempts:)
    attempts = 0
    begin
      attempts += 1
      yield attempts
    rescue TransientError
      retry if attempts < max_attempts
      # BUG: forgot to re-raise after exhausting attempts - the caller
      # never learns the retries ran out.
    end
  end
end
