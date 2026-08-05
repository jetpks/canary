class CreditsReel
  def initialize(entries)
    @entries = entries
  end

  def names
    @entries.map { |entry| entry.contributor.display_name }
  end

  def handles
    @entries.map { |entry| entry.contributor.handle }
  end
end
