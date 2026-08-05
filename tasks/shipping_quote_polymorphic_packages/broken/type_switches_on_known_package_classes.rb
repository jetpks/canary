class ShippingQuote
  def initialize(packages)
    @packages = packages
  end

  def total_cost
    @packages.sum do |package|
      case package
      when StandardPackage, PriorityPackage
        package.shipping_cost
      else
        raise ArgumentError, "unknown package type: #{package.class}"
      end
    end
  end

  def labels
    @packages.map(&:tracking_label)
  end
end
