require "test_helper"

class DashboardsControllerTest < ActionDispatch::IntegrationTest
  test "dashboard requires login" do
    get root_path
    assert_redirected_to new_session_path
  end

  test "dashboard displays only the current users balance and collection" do
    sign_in_as users(:two)
    get root_path
    assert_response :success
    assert_select "h1", "Hallo, trader_two!"
    assert_select "dd", "1000 Coins"
    assert_select "dd", "1 Karte"
    assert_select "form[action=?]", session_path
  end
end
