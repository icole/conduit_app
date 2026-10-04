require "test_helper"

# Images in rich text are shown resized (active_storage/blobs/_blob), with
# vips. image_processing 2 stopped bringing ruby-vips along, and nothing
# resized an image in the tests, so the upgrade passed CI while breaking it.
class ImageVariantTest < ActiveSupport::TestCase
  test "an uploaded image can be resized" do
    blob = ActiveStorage::Blob.create_and_upload!(io: file_fixture("test_image.png").open, filename: "test_image.png")

    variant = blob.variant(resize_to_limit: [ 1, 1 ]).processed

    assert variant.image.blob.present?
  end
end
