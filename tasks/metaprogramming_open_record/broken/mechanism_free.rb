class OpenRecord
  def initialize(**attrs)
    attrs.each { |key, value| define_singleton_method(key) { value } }
  end
end
