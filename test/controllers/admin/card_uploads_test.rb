require "test_helper"

class Admin::CardUploadsTest < ActionDispatch::IntegrationTest
  setup do
    users(:one).update!(role: :admin)
    sign_in_as users(:one)
  end

  def uploaded_png
    Rack::Test::UploadedFile.new(Rails.root.join("public/icon.png"), "image/png")
  end

  test "admin can create a card type with an uploaded image and download it" do
    get new_admin_brainrot_type_path
    assert_select "form[enctype='multipart/form-data']"
    assert_select "input[type=file][name='brainrot_type[image]']"
    assert_difference [ "BrainrotType.count", "ActiveStorage::Attachment.count", "AdminActivity.count" ], 1 do
      post admin_brainrot_types_path, params: { brainrot_type: {
        name: "Uploaded character", rarity: "rare", base_value: 120, image: uploaded_png
      } }
    end
    assert_redirected_to admin_brainrot_types_path
    type = BrainrotType.find_by!(name: "Uploaded character")
    assert type.image.attached?
    assert_equal "image/png", type.image.content_type
    assert_equal File.binread(Rails.root.join("public/icon.png")), type.image.download
    assert_match "icon.png", AdminActivity.last.details.fetch("image").last

    get edit_admin_brainrot_type_path(type)
    assert_select ".admin-image-preview img[src*='/rails/active_storage/']"
    assert_select "input[name='brainrot_type[remove_image]']"
    get rails_blob_path(type.image, only_path: true)
    assert_response :redirect
    follow_redirect!
    assert_response :success
    assert_equal "image/png", response.media_type
  end

  test "uploads override links and can be replaced or removed" do
    type = brainrot_types(:one)
    type.update!(image_url: "https://example.test/fallback.png")
    patch admin_brainrot_type_path(type), params: { brainrot_type: { image: uploaded_png } }
    assert_redirected_to admin_brainrot_types_path
    first_blob = type.reload.image.blob.id
    get inventory_index_path
    assert_select ".collection-art img[src*='/rails/active_storage/']"
    assert_select ".collection-art img[src=?]", type.image_url, count: 0

    patch admin_brainrot_type_path(type), params: { brainrot_type: { image: uploaded_png } }
    assert_redirected_to admin_brainrot_types_path
    assert_not_equal first_blob, type.reload.image.blob.id
    patch admin_brainrot_type_path(type), params: { brainrot_type: { remove_image: "1" } }
    assert_redirected_to admin_brainrot_types_path
    assert_not type.reload.image.attached?
    assert_nil AdminActivity.last.details.fetch("image").last
    get inventory_index_path
    assert_select ".collection-art img[src=?]", type.image_url
  end

  test "invalid and oversized files are rejected without saving or auditing" do
    Tempfile.create([ "fake-card", ".png" ]) do |file|
      file.binmode
      file.write("<svg onload='alert(1)'></svg>")
      file.flush
      assert_no_difference [ "ActiveStorage::Blob.count", "ActiveStorage::Attachment.count", "AdminActivity.count" ] do
        patch admin_brainrot_type_path(brainrot_types(:one)), params: {
          brainrot_type: { image: Rack::Test::UploadedFile.new(file.path, "image/png") }
        }
        assert_response :unprocessable_entity
        assert_select "[role=alert]", text: /Bilddatei|PNG/
      end
      file.rewind
      file.write(File.binread(Rails.root.join("public/icon.png")) + "x" * 5.megabytes)
      file.flush
      patch admin_brainrot_type_path(brainrot_types(:one)), params: {
        brainrot_type: { image: Rack::Test::UploadedFile.new(file.path, "image/png") }
      }
      assert_response :unprocessable_entity
      assert_select "[role=alert]", text: /5 MB/
    end
    assert_not brainrot_types(:one).reload.image.attached?
  end

  test "failed edits keep the existing upload" do
    type = brainrot_types(:one)
    patch admin_brainrot_type_path(type), params: { brainrot_type: { image: uploaded_png } }
    blob_id = type.reload.image.blob.id
    patch admin_brainrot_type_path(type), params: { brainrot_type: { name: "", remove_image: "1" } }
    assert_response :unprocessable_entity
    assert_equal blob_id, type.reload.image.blob.id
    patch admin_brainrot_type_path(type), params: { brainrot_type: { name: "", image: uploaded_png } }
    assert_response :unprocessable_entity
    assert_equal blob_id, type.reload.image.blob.id
  end

  test "traders cannot upload and signed blob IDs are not accepted as files" do
    sign_in_as users(:two)
    assert_no_difference "ActiveStorage::Attachment.count" do
      patch admin_brainrot_type_path(brainrot_types(:one)), params: { brainrot_type: { image: uploaded_png } }
      assert_response :forbidden
    end
    sign_in_as users(:one)
    patch admin_brainrot_type_path(brainrot_types(:one)), params: { brainrot_type: { image: "forged-blob-id" } }
    assert_response :bad_request
  end

  test "unused direct uploads cannot bypass the admin form" do
    assert_no_difference "ActiveStorage::Blob.count" do
      post "/rails/active_storage/direct_uploads", params: {
        blob: { filename: "unvalidated.svg", byte_size: 10, checksum: "fake", content_type: "image/svg+xml" }
      }
      assert_response :not_found
    end
  end

  test "uploads require a csrf token" do
    previous = ActionController::Base.allow_forgery_protection
    ActionController::Base.allow_forgery_protection = true
    assert_no_difference "ActiveStorage::Attachment.count" do
      patch admin_brainrot_type_path(brainrot_types(:one)), params: { brainrot_type: { image: uploaded_png } }
      assert_response :unprocessable_entity
    end
  ensure
    ActionController::Base.allow_forgery_protection = previous
  end
end
