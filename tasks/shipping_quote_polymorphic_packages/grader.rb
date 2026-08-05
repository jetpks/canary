class StandardPackage
  def initialize(weight_ounces)
    @weight_ounces = weight_ounces
  end

  def shipping_cost
    @weight_ounces * 12
  end

  def tracking_label
    "STD-#{@weight_ounces}oz"
  end
end

class PriorityPackage
  def initialize(weight_ounces)
    @weight_ounces = weight_ounces
  end

  def shipping_cost
    900
  end

  def tracking_label
    "PRI-#{@weight_ounces}oz"
  end
end

# A shape the statement's illustration never mentions - charged per pallet,
# not per unit of weight.
class BulkPalletPackage
  def initialize(pallet_count)
    @pallet_count = pallet_count
  end

  def shipping_cost
    @pallet_count * 4500
  end

  def tracking_label
    "PALLET-#{@pallet_count}"
  end
end

class ShippingQuoteGraderTest < Minitest::Test
  def test_total_cost_sums_shipping_cost_across_a_mix_of_standard_and_priority_packages
    quote = ShippingQuote.new([StandardPackage.new(10), PriorityPackage.new(2)])
    assert_equal(10 * 12 + 900, quote.total_cost)
  end

  def test_total_cost_includes_a_package_shape_the_statement_never_illustrated
    quote = ShippingQuote.new([StandardPackage.new(10), BulkPalletPackage.new(2)])
    assert_equal(10 * 12 + 2 * 4500, quote.total_cost)
  end

  def test_total_cost_with_only_the_unillustrated_shape
    quote = ShippingQuote.new([BulkPalletPackage.new(3)])
    assert_equal(3 * 4500, quote.total_cost)
  end

  def test_labels_returns_tracking_label_for_each_package_in_order
    quote = ShippingQuote.new([StandardPackage.new(5), BulkPalletPackage.new(1), PriorityPackage.new(3)])
    assert_equal ["STD-5oz", "PALLET-1", "PRI-3oz"], quote.labels
  end
end
