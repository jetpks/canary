class CreditsReel
  def initialize(entries)
    @entries = entries
  end

  def names
    @entries.map(&:display_name)
  end

  def handles
    @entries.map(&:handle)
  end
end
