require 'test/unit'
require File.dirname(__FILE__) + '/../../lib/action_view/helpers/tag_helper'
require File.dirname(__FILE__) + '/../../lib/action_view/helpers/url_helper'

class TagHelperTest < Test::Unit::TestCase
  include ActionView::Helpers::TagHelper
  include ActionView::Helpers::UrlHelper

  def test_tag
    assert_equal "<p class=\"show\" />", tag("p", "class" => "show")
  end
  
  def test_content_tag
    assert_equal "<a href=\"create\">Create</a>", content_tag("a", "Create", "href" => "create")
  end

  def test_mail_to_with_javascript
  	assert_equal "<script type=\"text/javascript\" language=\"javascript\">eval(unescape('%64%6f%63%75%6d%65%6e%74%2e%77%72%69%74%65%28%27%3c%61%20%68%72%65%66%3d%22%6d%61%69%6c%74%6f%3a%6d%65%40%64%6f%6d%61%69%6e%2e%63%6f%6d%22%3e%4d%79%20%65%6d%61%69%6c%3c%2f%61%3e%27%29%3b'))</script>", mail_to("me@domain.com", "My email", :encode => "javascript")
  end

  def test_mail_to_with_hex
  	assert_equal "<a href=\"mailto:%6d%65@%64%6f%6d%61%69%6e.%63%6f%6d\">My email</a>", mail_to("me@domain.com", "My email", :encode => "hex")
  end

  def test_mail_to
  	assert_equal "<a href=\"mailto:me@domain.com\">My email</a>", mail_to("me@domain.com", "My email")
  end

  # FIXME: Test form tag
end