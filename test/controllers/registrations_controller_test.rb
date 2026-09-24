require "test_helper"

class RegistrationsControllerTest < ActionDispatch::IntegrationTest
  setup { Rails.cache.clear }

  test "registration form is public and has password rules" do
    get new_registration_path
    assert_response :success
    assert_select "input[name='user[password]'][minlength='12']"
  end

  test "registration creates a trader and logs in without accepting privileged fields" do
    assert_difference [ "User.count", "Session.count" ], 1 do
      post registration_path, params: { user: registration_attributes.merge(role: "admin", coins: 999_999) }
    end
    user = User.find_by!(email_address: "new@example.com")
    assert user.trader?
    assert_equal 1_000, user.coins
    assert user.authenticate("a secure passphrase")
    assert_not_equal "a secure passphrase", user.password_digest
    assert_redirected_to packs_index_path(anchor: "starter-pack")
    follow_redirect!
    assert_response :success
    assert_select "#starter-pack"
    assert_select "button", "Abmelden"
  end

  test "invalid and duplicate registrations do not create users or sessions" do
    [
      { password: "short", password_confirmation: "short" },
      { email_address: " ONE@EXAMPLE.COM " },
      { password_confirmation: "different password" },
      { email_address: "not-an-email" }
    ].each do |invalid|
      assert_no_difference [ "User.count", "Session.count" ] do
        post registration_path, params: { user: registration_attributes.merge(invalid) }
      end
      assert_response :unprocessable_entity
      assert_select "[role=alert]"
      assert_select "input[type=password][value]", count: 0
    end
  end

  private

  def registration_attributes
    { username: "new_trader", email_address: " NEW@EXAMPLE.COM ",
      password: "a secure passphrase", password_confirmation: "a secure passphrase" }
  end
end
