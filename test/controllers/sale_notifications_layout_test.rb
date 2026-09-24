require "test_helper"

class SaleNotificationsLayoutTest < ActionDispatch::IntegrationTest
  test "guest pages do not subscribe to sale notifications" do
    get new_session_path
    assert_select "[data-controller=sale-notifications]", count: 0
  end

  test "authenticated pages expose only their own notification region" do
    sign_in_as users(:one)
    get root_path
    assert_select "[data-controller=sale-notifications][data-sale-notifications-user-id-value='#{users(:one).id}'][data-turbo-permanent]"
    assert_select "[data-wallet-user='#{users(:one).id}']", count: 2
    assert_select "meta[name=action-cable-url]"
  end
end
