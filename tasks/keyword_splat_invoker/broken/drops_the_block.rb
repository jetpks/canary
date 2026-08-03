class Invoker
  def self.call(target, *args, **kwargs, &block)
    target.call(*args, **kwargs)
  end
end
