class Finder
  def self.first_matching(source, &predicate)
    source.lazy.select(&predicate)
  end
end
