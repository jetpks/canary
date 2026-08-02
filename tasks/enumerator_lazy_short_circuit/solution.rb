class Finder
  def self.first_matching(source, n, &predicate)
    source.lazy.select(&predicate).first(n)
  end
end
