# frozen_string_literal: true

require "test_helper"

# Tests for ActiveStorage authorization using the Hey/Basecamp approach
# Reference: https://discuss.rubyonrails.org/t/activestorage-authentication/79273
class ActiveStorageAuthorizationTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    @document = documents(:native_doc)
  end

  test "unauthenticated API request cannot access blob and receives 401" do
    blob = create_test_blob
    get rails_blob_path(blob), headers: { "Accept" => "application/json" }
    assert_response :unauthorized
  end

  test "authenticated user can access standalone blob" do
    sign_in_user(uid: @user.uid, email: @user.email)
    blob = create_test_blob

    get rails_blob_path(blob)
    # Should redirect to the actual file location
    assert_response :redirect
  end

  test "unauthenticated HTML request redirects to login" do
    blob = create_test_blob
    get rails_blob_path(blob), headers: { "Accept" => "text/html" }
    assert_redirected_to login_path
    assert_match(/log in/i, flash[:alert])
  end

  test "authenticated user can access document image from same community" do
    sign_in_user(uid: @user.uid, email: @user.email)
    attach_image_to_document(@document)

    get rails_blob_path(@document.images.first)
    assert_response :redirect
  end

  test "user cannot access document image from different community" do
    # Create a document in a different community
    other_community = communities(:other_community)
    other_document = nil

    ActsAsTenant.with_tenant(other_community) do
      other_document = Document.create!(
        title: "Other Community Doc",
        storage_type: :native,
        content: "<p>Test</p>"
      )
      other_document.images.attach(
        io: File.open(Rails.root.join("test/fixtures/files/test_image.png")),
        filename: "secret_image.png",
        content_type: "image/png"
      )
    end

    # Sign in as user from crow_woods community
    sign_in_user(uid: @user.uid, email: @user.email)

    # Try to access the image from other community's document
    get rails_blob_path(other_document.images.first)
    assert_response :forbidden
  end

  private

  def create_test_blob
    ActiveStorage::Blob.create_and_upload!(
      io: File.open(Rails.root.join("test/fixtures/files/test_image.png")),
      filename: "test_image.png",
      content_type: "image/png"
    )
  end

  def attach_image_to_document(document)
    document.images.attach(
      io: File.open(Rails.root.join("test/fixtures/files/test_image.png")),
      filename: "test_image.png",
      content_type: "image/png"
    )
  end
end
