class Proxy
  def initialize(target)
    @target = target
  end

  def method_missing(name, *args, **kwargs, &block)
    return @target.public_send(name, *args, **kwargs, &block) if @target.respond_to?(name)

    super
  end

  def respond_to_missing?(name, include_private = false)
    @target.respond_to?(name, include_private) || super
  end
end
