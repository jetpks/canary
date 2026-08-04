class TokenStream
  def initialize(tokens)
    @tokens = tokens.dup
  end

  def next
    raise StopIteration if @tokens.empty?

    @tokens.shift
  end

  def peek
    raise StopIteration if @tokens.empty?

    @tokens.first
  end

  def rewind
    raise NotImplementedError, "no way to recover already-shifted tokens"
  end
end
