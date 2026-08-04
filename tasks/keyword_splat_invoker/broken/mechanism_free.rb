class Invoker
  def self.call(target, *args, &block)
    target.call(*args, &block)
  end
end
