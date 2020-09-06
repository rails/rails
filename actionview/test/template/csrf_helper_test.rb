# frozen_string_literal: true

require 'abstract_unit'

class CsrfHelperTest < ActiveSupport::TestCase
  cattr_accessor :request_forgery, default: false

  include ActionView::Helpers::CsrfHelper
  include ActionView::Helpers::TagHelper
  include Rails::Dom::Testing::Assertions::DomAssertions

  def test_csrf_meta_tags_without_request_forgery_protection
    assert_dom_equal '', csrf_meta_tags
  end

  def test_csrf_meta_tags_with_request_forgery_protection
    self.request_forgery = true

    assert_dom_equal <<~DOM.chomp, csrf_meta_tags
      <meta name="csrf-param" content="form_token" />
      <meta name="csrf-token" content="secret" />
    DOM
  ensure
    self.request_forgery = false
  end

  def test_csrf_meta_tags_without_protect_against_forgery_method
    self.class.undef_method(:protect_against_forgery?)

    assert_dom_equal '', csrf_meta_tags
  ensure
    self.class.define_method(:protect_against_forgery?) { request_forgery }
  end

  def protect_against_forgery?
    request_forgery
  end

  def form_authenticity_token(**)
    'secret'
  end

  def request_forgery_protection_token
    'form_token'
  end
end
