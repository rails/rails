# frozen_string_literal: true

require "abstract_unit"

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
    assert_response_code_range 200..299, :successful?
    assert_response_code_range [404],    :not_found?
    assert_response_code_range 300..399, :redirection?
    assert_response_code_range 500..599, :server_error?
    assert_response_code_range 400..499, :client_error?
  end

  test "response parsing" do
    response = ActionDispatch::TestResponse.create(200, {}, "")
    assert_equal response.body, response.parsed_body

    response = ActionDispatch::TestResponse.create(200, { "Content-Type" => "application/json" }, '{ "foo": "fighters" }')
    assert_equal({ "foo" => "fighters" }, response.parsed_body)

    response_body = "<script>Hello</script> World &"
    response = ActionDispatch::TestResponse.create(200, {}, CGI.escapeHTML(response_body))
    assert_equal response.unescaped_body, response_body
  end

  test "response status aliases deprecated" do
    response = ActionDispatch::TestResponse.create
    assert_deprecated { response.success? }
    assert_deprecated { response.missing? }
    assert_deprecated { response.error? }
  end
end
