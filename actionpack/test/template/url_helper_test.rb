require 'test/unit'
require File.dirname(__FILE__) + '/../../lib/action_view/helpers/url_helper'

class UrlHelperTest < Test::Unit::TestCase
  include ActionView::Helpers::UrlHelper

  # todo: missing test cases
  def test_link_tag
    assert true
  end
end