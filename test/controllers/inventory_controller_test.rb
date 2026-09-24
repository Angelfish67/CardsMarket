require "test_helper"

class InventoryControllerTest < ActionDispatch::IntegrationTest
  test "guests are redirected to login" do
    get inventory_index_path
    assert_redirected_to new_session_path
  end

  test "signed in users can access index" do
    sign_in_as users(:one)
    get inventory_index_path
    assert_response :success
  end
end
