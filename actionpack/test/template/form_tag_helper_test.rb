require 'test/unit'
require File.dirname(__FILE__) + '/../../lib/action_view/helpers/form_tag_helper'

class TagHelperTest < Test::Unit::TestCase
  include ActionView::Helpers::TagHelper
  include ActionView::Helpers::FormTagHelper

  MethodToTag = {
    %(text_field_tag("title", "Hello!")) => %(<input id="title" name="title" type="text" value="Hello!" />),
    %(text_field_tag("title", "Hello!", "class" => "admin")) => %(<input class="admin" id="title" name="title" type="text" value="Hello!" />),
    %(hidden_field_tag "id", 3) => %(<input id="id" name="id" type="hidden" value="3" />),
    %(password_field_tag) => %(<input id="password" name="password" type="password" value="" />),
    %(text_area_tag("body", "hello world", :size => "20x40")) => %(<textarea cols="20" id="body" name="body" rows="40">hello world</textarea>),
    %(check_box_tag("admin")) => %(<input id="admin" name="admin" type="checkbox" value="1" />),
    %(radio_button_tag("people", "david")) => %(<input id="people" name="people" type="radio" value="david" />),
    %(select_tag("people", "<option>david</option>")) => %(<select id="people" name="people"><option>david</option></select>),
  }

  def test_tags
    MethodToTag.each { |method, tag| assert_equal(eval(method), tag) }
  end
end