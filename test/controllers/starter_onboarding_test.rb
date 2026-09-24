require "test_helper"

class StarterOnboardingTest < ActionDispatch::IntegrationTest
  setup { Rails.cache.clear }

  def login
    post session_path, params: { email_address: users(:one).email_address, password: "secure password" }
  end

  test "a dashboard visit before the first login still leads to the starter" do
    get root_path
    login
    assert_redirected_to packs_index_path(anchor: "starter-pack")
    follow_redirect!
    assert_select "#starter-pack"
    assert_select "form[action=?]", open_pack_path(packs(:starter))
  end

  test "claimed starters or missing starter packs lead to the dashboard" do
    PackOpener.call(user: users(:one), pack: packs(:starter))
    login
    assert_redirected_to root_path
    users(:one).update!(starter_pack_opened_at: nil)
    login
    assert_redirected_to root_path
  end

  test "unavailable starter packs do not lead to an empty onboarding screen" do
    Pack.where(starter: true).update_all(active: false)
    login
    assert_redirected_to root_path
  end
end
