class OpenRecord
  def initialize(**attrs)
    @attrs = attrs
  end

  def method_missing(name, *args)
    key = name.to_s
    if key.end_with?("=")
      # BUG: computes the key but never stores the value.
      key.chomp("=").to_sym
    elsif @attrs.key?(name)
      @attrs[name]
    else
      super
    end
  end

  def respond_to_missing?(name, include_private = false)
    @attrs.key?(name) || name.to_s.end_with?("=") || super
  end
end
