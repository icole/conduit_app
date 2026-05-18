require "test_helper"

class EncodingErrorHandlerTest < ActiveSupport::TestCase
  def setup
    @app = ->(env) { raise Encoding::CompatibilityError, "incompatible character encodings: UTF-16LE and UTF-8" }
    @middleware = EncodingErrorHandler.new(@app)
  end

  test "returns 400 for Encoding::CompatibilityError" do
    status, headers, body = @middleware.call({})
    assert_equal 400, status
    assert_equal "text/plain", headers["content-type"]
    assert_equal [ "Bad Request" ], body
  end

  test "returns 400 for Encoding::InvalidByteSequenceError" do
    app = ->(env) { raise Encoding::InvalidByteSequenceError }
    middleware = EncodingErrorHandler.new(app)

    status, _, _ = middleware.call({})
    assert_equal 400, status
  end

  test "passes through normal requests" do
    app = ->(env) { [ 200, { "content-type" => "text/html" }, [ "OK" ] ] }
    middleware = EncodingErrorHandler.new(app)

    status, _, body = middleware.call({})
    assert_equal 200, status
    assert_equal [ "OK" ], body
  end
end
