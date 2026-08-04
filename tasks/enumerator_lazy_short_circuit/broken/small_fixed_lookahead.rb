class Finder
  def self.first_matching(source, &predicate)
    source.lazy.select(&predicate).first(10)
  end
end
