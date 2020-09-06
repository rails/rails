# frozen_string_literal: true

require 'abstract_unit'

module ContentNegotiation
  # This has no layout and it works
  class BasicController < ActionController::Base
    self.view_paths = [ActionView::FixtureResolver.new(
      'content_negotiation/basic/hello.html.erb' => 'Hello world <%= request.formats.first.to_s %>!'
    )]

    def all
      render plain: formats.inspect
    end
  end

  class TestContentNegotiation < Rack::TestCase
    test 'A */* Accept header will return HTML' do
      get '/content_negotiation/basic/hello', headers: { 'HTTP_ACCEPT' => '*/*' }
      assert_body 'Hello world */*!'
    end

    test 'A js or */* Accept header will return HTML' do
      get '/content_negotiation/basic/hello', headers: { 'HTTP_ACCEPT' => 'text/javascript, */*' }
      assert_body 'Hello world text/html!'
    end

    test 'A js or */* Accept header on xhr will return JavaScript' do
      get '/content_negotiation/basic/hello', headers: { 'HTTP_ACCEPT' => 'text/javascript, */*' }, xhr: true
      assert_body 'Hello world text/javascript!'
    end

    test 'Unregistered mimes are ignored' do
      get '/content_negotiation/basic/all', headers: { 'HTTP_ACCEPT' => 'text/plain, mime/another' }
      assert_body '[:text]'
    end
  end
end
