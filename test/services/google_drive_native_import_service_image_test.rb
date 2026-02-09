require "test_helper"

class GoogleDriveNativeImportServiceImageTest < ActiveSupport::TestCase
  setup do
    @community = communities(:crow_woods)
    @service = GoogleDriveNativeImportService.new(@community)
  end

  test "clean_html converts base64 data URI images to attachments" do
    # A minimal valid PNG in base64
    png_base64 = "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg=="
    html = %(<body><p>Text</p><img src="data:image/png;base64,#{png_base64}" alt="test"></body>)

    ActsAsTenant.with_tenant(@community) do
      doc = Document.create!(title: "Test", storage_type: :native, content: "")

      assert_equal 0, doc.images.count

      result = @service.send(:clean_html, html, doc)

      # The data URI should be replaced with an ActiveStorage URL
      assert_not_includes result, "data:image/png;base64"
      assert_includes result, "/rails/active_storage/blobs"
      assert_equal 1, doc.images.count
    end
  end

  test "base64_data_uri? correctly identifies data URIs" do
    assert @service.send(:base64_data_uri?, "data:image/png;base64,abc123")
    assert @service.send(:base64_data_uri?, "data:image/jpeg;base64,/9j/4AAQ")
    assert @service.send(:base64_data_uri?, "data:image/gif;base64,R0lGOD")

    assert_not @service.send(:base64_data_uri?, "https://example.com/image.png")
    assert_not @service.send(:base64_data_uri?, "data:text/plain;base64,abc")
    assert_not @service.send(:base64_data_uri?, nil)
    assert_not @service.send(:base64_data_uri?, "")
  end

  test "clean_html identifies google-hosted image URLs" do
    # Test that the service correctly identifies Google-hosted URLs
    assert @service.send(:google_hosted_image?, "https://lh3.googleusercontent.com/abc123")
    assert @service.send(:google_hosted_image?, "https://lh4.googleusercontent.com/xyz")
    assert @service.send(:google_hosted_image?, "https://lh5.googleusercontent.com/test")
    assert @service.send(:google_hosted_image?, "https://docs.google.com/drawings/image123")

    assert_not @service.send(:google_hosted_image?, "https://example.com/image.png")
    assert_not @service.send(:google_hosted_image?, "data:image/png;base64,abc")
    assert_not @service.send(:google_hosted_image?, "https://cdn.example.com/photo.jpg")
  end

  test "clean_html preserves non-Google external images" do
    external_url = "https://example.com/image.png"
    html = %(<body><img src="#{external_url}" alt="external"></body>)

    ActsAsTenant.with_tenant(@community) do
      doc = Document.create!(title: "Test", storage_type: :native, content: "")

      result = @service.send(:clean_html, html, doc)

      # External non-Google images should be preserved as-is
      assert_includes result, external_url
    end
  end

  test "clean_html removes Google tracking images" do
    html = '<body><p>Text</p><img src="https://www.google.com/a/cpanelemaildomain.com/images/tracking.gif"></body>'

    ActsAsTenant.with_tenant(@community) do
      doc = Document.create!(title: "Test", storage_type: :native, content: "")
      result = @service.send(:clean_html, html, doc)

      assert_not_includes result, "google.com/a/"
    end
  end

  test "Document model has images attachment" do
    ActsAsTenant.with_tenant(@community) do
      doc = Document.create!(title: "Test", storage_type: :native, content: "test")

      assert_respond_to doc, :images
      assert_not doc.images.attached?

      # Attach an image
      doc.images.attach(
        io: File.open(Rails.root.join("test/fixtures/files/test_image.png")),
        filename: "test.png",
        content_type: "image/png"
      )

      assert doc.images.attached?
      assert_equal 1, doc.images.count
    end
  end
end
