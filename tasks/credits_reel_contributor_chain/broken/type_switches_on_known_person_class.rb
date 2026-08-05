class CreditsReel
  def initialize(entries)
    @entries = entries
  end

  def names
    @entries.map do |entry|
      person = entry.contributor
      case person
      when CreditedPerson
        person.display_name
      else
        raise ArgumentError, "unknown contributor type: #{person.class}"
      end
    end
  end

  def handles
    @entries.map { |entry| entry.contributor.handle }
  end
end
