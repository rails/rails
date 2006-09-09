require "#{File.dirname(__FILE__)}/abstract_unit"

class ConnectionTest < Test::Unit::TestCase
  Response = Struct.new(:code)

  def setup
    @conn = ActiveResource::Connection.new('http://localhost')
  end

  def test_handle_response
    # 2xx and 3xx are valid responses.
    [200, 299, 300, 399].each do |code|
      expected = Response.new(code)
      assert_equal expected, @conn.send(:handle_response, expected)
    end

    # 404 is a missing resource.
    assert_response_raises ActiveResource::ResourceNotFound, 404

    # 400 is a validation error
    assert_response_raises ActiveResource::ResourceInvalid, 400

    # 409 is an optimistic locking error
    assert_response_raises ActiveResource::ResourceConflict, 409

    # 4xx are client errors.
    [401, 499].each do |code|
      assert_response_raises ActiveResource::ClientError, code
    end

    # 5xx are server errors.
    [500, 599].each do |code|
      assert_response_raises ActiveResource::ServerError, code
    end

    # Others are unknown.
    [199, 600].each do |code|
      assert_response_raises ActiveResource::ConnectionError, code
    end
  end

  protected
    def assert_response_raises(klass, code)
      assert_raise(klass, "Expected response code #{code} to raise #{klass}") do
        @conn.send(:handle_response, Response.new(code))
      end
    end
end
