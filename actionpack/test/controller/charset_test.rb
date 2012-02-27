require 'abstract_unit'

class CharsetController < ActionController::Base

  def render_from_charset
    response.charset = 'Shift_JIS'
    render :inline => "<%= charset_meta_tag %>"
  end

  def render_from_default_charset
    render :inline => "<%= charset_meta_tag %>"
  end

  def render_from_argument
    render :inline => "<%= charset_meta_tag 'Shift_JIS' %>"
  end

end

class CharsetTest < ActionController::TestCase
  tests CharsetController

  def test_render_from_charset
    get :render_from_charset
    assert_match(/Shift_JIS/, @response.body)
  end

  def test_render_from_default_charset
    get :render_from_default_charset
    assert_match(/utf-8/, @response.body)
  end

  def test_render_from_argument
    get :render_from_argument
    assert_match(/Shift_JIS/, @response.body)
  end

end
