class DeliveryGraderTest < Minitest::Test
  def test_route_without_a_block_returns_the_logged_status
    delivery = audited_delivery
    delivery.log("T1", "in_transit")

    assert_equal "in_transit", route_without_block(delivery, "T1")
  end

  def test_route_without_a_block_returns_nil_for_an_unlogged_id
    delivery = audited_delivery

    assert_nil route_without_block(delivery, "T9")
  end

  def test_route_with_a_block_yields_the_tracking_id_and_status_and_returns_the_blocks_value
    delivery = audited_delivery
    delivery.log("T1", "in_transit")

    assert_equal ["T1", "in_transit", "handled"], route_with_block(delivery, "T1")
  end

  def test_route_with_a_block_yields_a_nil_status_for_an_unlogged_id
    delivery = audited_delivery

    assert_equal ["T9", nil, "handled"], route_with_block(delivery, "T9")
  end

  def test_audit_trail_accumulates_every_route_call_in_order_regardless_of_block_or_status
    delivery = audited_delivery
    delivery.log("T1", "in_transit")

    route_without_block(delivery, "T1")
    route_without_block(delivery, "T9")
    route_with_block(delivery, "T1")
    route_with_block(delivery, "T9")

    assert_equal [["T1", "in_transit"], ["T9", nil], ["T1", "in_transit"], ["T9", nil]], delivery.audit_trail
  end

  private

  # Written against Delivery's documented #route contract alone - exercised
  # here through the AuditedDelivery subtype.
  def audited_delivery
    AuditedDelivery.new
  end

  def route_without_block(delivery, tracking_id)
    delivery.route(tracking_id)
  end

  def route_with_block(delivery, tracking_id)
    delivery.route(tracking_id) { |id, status| [id, status, "handled"] }
  end
end
