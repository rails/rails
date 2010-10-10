require 'abstract_unit'

class TestResponseTest < ActiveSupport::TestCase
  def assert_response_code_range(range, predicate)
    response = ActionDispatch::TestResponse.new
    (0..599).each do |status|
      response.status = status
      assert_equal range.include?(status), response.send(predicate),
                   "ActionDispatch::TestResponse.new(#{status}).#{predicate}"
    end
  end

  test "helpers" do
    assert_response_code_range 200..299, :success?
    assert_response_code_range [404],    :missing?
    assert_response_code_range 300..399, :redirect?
    assert_response_code_range 500..599, :error?
    assert_response_code_range 500..599, :server_error?
    assert_response_code_range 400..499, :client_error?
  end
end
