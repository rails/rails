# frozen_string_literal: true

require 'abstract_unit'

class WithCookiesController < ActionController::API
  include ActionController::Cookies

  def with_cookies
    render plain: cookies[:foobar]
  end
end

class WithCookiesTest < ActionController::TestCase
  tests WithCookiesController

  def test_with_cookies
    request.cookies[:foobar] = 'bazbang'

    get :with_cookies

    assert_equal 'bazbang', response.body
  end
end
