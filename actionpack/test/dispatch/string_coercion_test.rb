require 'abstract_unit'

class StringCoercionTest < ActiveSupport::TestCase
  test "body responds to each" do
    original_body = []
    body = ActionDispatch::StringCoercion::UglyBody.new(original_body)

    assert original_body.respond_to?(:each)
    assert body.respond_to?(:each)
  end

  test "body responds to to_path" do
    original_body = []
    def original_body.to_path; end
    body = ActionDispatch::StringCoercion::UglyBody.new(original_body)

    assert original_body.respond_to?(:to_path)
    assert body.respond_to?(:to_path)
  end

  test "body does not responds to to_path" do
    original_body = []
    body = ActionDispatch::StringCoercion::UglyBody.new(original_body)

    assert !original_body.respond_to?(:to_path)
    assert !body.respond_to?(:to_path)
  end

  test "calls to_s on body parts" do
    app = lambda { |env|
      [200, {'Content-Type' => 'html'}, [1, 2, 3]]
    }
    app = ActionDispatch::StringCoercion.new(app)
    parts = []
    status, headers, body = app.call({})
    body.each { |part| parts << part }

    assert_equal %w( 1 2 3 ), parts
  end
end
