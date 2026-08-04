class SafeCaller
  def self.call(callable, *args, default:)
    if callable.arity >= 0 && callable.arity != args.size
      default
    else
      callable.call(*args)
    end
  end
end
