class Finder
  def self.first_matching(source, n, &predicate)
    source.lazy.first(n).select(&predicate)
  end
end
