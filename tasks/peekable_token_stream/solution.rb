class TokenStream
  def initialize(tokens)
    @tokens = tokens
    @position = 0
  end

  def next
    raise StopIteration if @position >= @tokens.size

    token = @tokens[@position]
    @position += 1
    token
  end

  def peek
    raise StopIteration if @position >= @tokens.size

    @tokens[@position]
  end

  def rewind
    @position = 0
  end
end
