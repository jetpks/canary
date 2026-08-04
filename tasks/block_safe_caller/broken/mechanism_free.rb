class SafeCaller
  def self.call(callable, *args, default:)
    callable.call(*args)
  end
end
