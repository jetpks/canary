CreditEntry = Struct.new(:contributor)
CreditedPerson = Struct.new(:display_name, :handle)

class LazyCreditEntry
  def initialize(&resolver)
    @resolver = resolver
  end

  def contributor
    @resolver.call
  end
end

class ComputedPerson
  def initialize(first, last, handle)
    @first = first
    @last = last
    @handle = handle
  end

  def display_name
    "#{@first} #{@last}"
  end

  def handle
    @handle
  end
end

class CreditsReelGraderTest < Minitest::Test
  def test_names_with_struct_based_entries_and_people
    reel = CreditsReel.new([
      CreditEntry.new(CreditedPerson.new("Ada Lovelace", "ada")),
      CreditEntry.new(CreditedPerson.new("Grace Hopper", "ghop"))
    ])

    assert_equal ["Ada Lovelace", "Grace Hopper"], reel.names
  end

  def test_handles_with_struct_based_entries_and_people
    reel = CreditsReel.new([
      CreditEntry.new(CreditedPerson.new("Ada Lovelace", "ada")),
      CreditEntry.new(CreditedPerson.new("Grace Hopper", "ghop"))
    ])

    assert_equal ["ada", "ghop"], reel.handles
  end

  def test_names_with_an_entry_and_person_shape_the_statement_never_illustrated
    reel = CreditsReel.new([LazyCreditEntry.new { ComputedPerson.new("Marie", "Curie", "mcurie") }])

    assert_equal ["Marie Curie"], reel.names
  end

  def test_handles_with_an_entry_and_person_shape_the_statement_never_illustrated
    reel = CreditsReel.new([LazyCreditEntry.new { ComputedPerson.new("Marie", "Curie", "mcurie") }])

    assert_equal ["mcurie"], reel.handles
  end

  def test_names_and_handles_with_a_mix_of_anticipated_and_unanticipated_shapes
    reel = CreditsReel.new([
      CreditEntry.new(CreditedPerson.new("Ada Lovelace", "ada")),
      LazyCreditEntry.new { ComputedPerson.new("Marie", "Curie", "mcurie") }
    ])

    assert_equal ["Ada Lovelace", "Marie Curie"], reel.names
    assert_equal ["ada", "mcurie"], reel.handles
  end
end
