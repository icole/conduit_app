class EncodingErrorHandler
  def initialize(app)
    @app = app
  end

  def call(env)
    @app.call(env)
  rescue Encoding::CompatibilityError, Encoding::InvalidByteSequenceError, Encoding::UndefinedConversionError
    [ 400, { "content-type" => "text/plain" }, [ "Bad Request" ] ]
  end
end
