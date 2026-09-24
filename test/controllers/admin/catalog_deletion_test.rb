require "test_helper"

class Admin::CatalogDeletionTest < ActionDispatch::IntegrationTest
  setup do
    users(:one).update!(role: :admin)
    @type = BrainrotType.create!(name: "Unused type", rarity: :rare, base_value: 100)
  end

  test "only admins can delete a type" do
    assert_no_difference "BrainrotType.count" do
      delete admin_brainrot_type_path(@type)
      assert_redirected_to new_session_path
      sign_in_as users(:two)
      delete admin_brainrot_type_path(@type)
      assert_response :forbidden
    end
  end

  test "deletion is audited and preserves a useful snapshot of the removed type" do
    sign_in_as users(:one)
    assert_difference "BrainrotType.count", -1 do
      assert_difference "AdminActivity.count", 1 do
        delete admin_brainrot_type_path(@type)
      end
    end
    assert_redirected_to admin_brainrot_types_path
    assert_equal "destroy", AdminActivity.last.action
    assert_equal @type.id, AdminActivity.last.subject_id
    assert_equal [ "Unused type", nil ], AdminActivity.last.details["name"]
  end

  test "referenced types cannot be deleted and produce no audit entry" do
    sign_in_as users(:one)
    assert_no_difference [ "BrainrotType.count", "BrainrotCard.count", "AdminActivity.count" ] do
      delete admin_brainrot_type_path(brainrot_types(:one))
    end
    assert_redirected_to admin_brainrot_types_path
    assert_match(/Deaktiviere/, flash[:alert])
    assert BrainrotType.exists?(brainrot_types(:one).id)
  end

  test "deleting a type requires CSRF protection" do
    sign_in_as users(:one)
    previous = ActionController::Base.allow_forgery_protection
    ActionController::Base.allow_forgery_protection = true
    assert_no_difference "BrainrotType.count" do
      delete admin_brainrot_type_path(@type)
      assert_response :unprocessable_entity
    end
  ensure
    ActionController::Base.allow_forgery_protection = previous
  end
end
