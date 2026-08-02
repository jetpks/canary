class Finder
  def self.first_matching(source, &predicate)
    source.select(&predicate)
  end
end
