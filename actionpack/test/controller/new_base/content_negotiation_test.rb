require 'abstract_unit'

module ContentNegotiation

  # This has no layout and it works
  class BasicController < ActionController::Base
    self.view_paths = [ActionView::FixtureResolver.new(
      "content_negotiation/basic/hello.html.erb" => "Hello world <%= request.formats.first.to_s %>!"
    )]
  end

  class TestContentNegotiation < Rack::TestCase
    test "A */* Accept header will return HTML" do
      get "/content_negotiation/basic/hello", {}, "HTTP_ACCEPT" => "*/*"
      assert_body "Hello world */*!"
    end
  end
end
