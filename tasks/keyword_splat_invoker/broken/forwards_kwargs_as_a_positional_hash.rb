class Invoker
  def self.call(target, *args, **kwargs, &block)
    target.call(*args, kwargs, &block)
  end
end
