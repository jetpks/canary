class Counter
  def self.storage
    @storage ||= {}
  end

  def initialize
    @count = 0
    @step_key = :"counter_step_#{object_id}"
  end

  def value
    @count
  end

  def bump
    @count += current_step
    self
  end

  def with_step(step)
    had_previous_step = self.class.storage.key?(@step_key)
    previous_step = self.class.storage[@step_key]
    self.class.storage[@step_key] = step
    yield
  ensure
    if had_previous_step
      self.class.storage[@step_key] = previous_step
    else
      self.class.storage.delete(@step_key)
    end
  end

  private

  def current_step
    self.class.storage.fetch(@step_key, 1)
  end

  def initialize_copy(other)
    super
    @step_key = :"counter_step_#{object_id}"
  end
end
