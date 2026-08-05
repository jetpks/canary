class ShippingQuote
  def initialize(packages)
    @packages = packages
  end

  def total_cost
    @packages.sum(&:shipping_cost)
  end

  def labels
    @packages.map(&:tracking_label).reverse
  end
end
