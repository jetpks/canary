class OpenRecord
  def initialize(**attrs)
    @attrs = attrs
  end

  def method_missing(name, *args)
    key = name.to_s
    if key.end_with?("=")
      @attrs[key.chomp("=").to_sym] = args.first
    elsif @attrs.key?(name)
      @attrs[name]
    else
      super
    end
  end
end
