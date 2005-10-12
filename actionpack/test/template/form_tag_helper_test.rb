require File.dirname(__FILE__) + '/../abstract_unit'

class FormTagHelperTest < Test::Unit::TestCase

  include ActionView::Helpers::UrlHelper
  include ActionView::Helpers::TagHelper
  include ActionView::Helpers::FormTagHelper

  def setup
    @controller = Class.new do
      def url_for(options, *parameters_for_method_reference)
        "http://www.example.com"
      end
    end
    @controller = @controller.new
  end

  def test_check_box_tag
    actual = check_box_tag "admin"
    expected = %(<input id="admin" name="admin" type="checkbox" value="1" />)
    assert_dom_equal expected, actual
  end

  def test_form_tag
    actual = form_tag
    expected = %(<form action="http://www.example.com" method="post">)
    assert_dom_equal expected, actual
  end

  def test_form_tag_multipart
    actual = form_tag({}, { 'multipart' => true })
    expected = %(<form action="http://www.example.com" enctype="multipart/form-data" method="post">)
    assert_dom_equal expected, actual
  end

  def test_hidden_field_tag
    actual = hidden_field_tag "id", 3
    expected = %(<input id="id" name="id" type="hidden" value="3" />)
    assert_dom_equal expected, actual
  end

  def test_password_field_tag
    actual = password_field_tag
    expected = %(<input id="password" name="password" type="password" />)
    assert_dom_equal expected, actual
  end

  def test_radio_button_tag
    actual = radio_button_tag "people", "david"
    expected = %(<input id="people" name="people" type="radio" value="david" />)
    assert_dom_equal expected, actual
  end

  def test_select_tag
    actual = select_tag "people", "<option>david</option>"
    expected = %(<select id="people" name="people"><option>david</option></select>)
    assert_dom_equal expected, actual
  end

  def test_text_area_tag_size_string
    actual = text_area_tag "body", "hello world", "size" => "20x40"
    expected = %(<textarea cols="20" id="body" name="body" rows="40">hello world</textarea>)
    assert_dom_equal expected, actual
  end

  def test_text_area_tag_size_symbol
    actual = text_area_tag "body", "hello world", :size => "20x40"
    expected = %(<textarea cols="20" id="body" name="body" rows="40">hello world</textarea>)
    assert_dom_equal expected, actual
  end

  def test_text_field_tag
    actual = text_field_tag "title", "Hello!"
    expected = %(<input id="title" name="title" type="text" value="Hello!" />)
    assert_dom_equal expected, actual
  end

  def test_text_field_tag_class_string
    actual = text_field_tag "title", "Hello!", "class" => "admin"
    expected = %(<input class="admin" id="title" name="title" type="text" value="Hello!" />)
    assert_dom_equal expected, actual
  end

  def test_boolean_optios
    assert_dom_equal %(<input checked="checked" disabled="disabled" id="admin" name="admin" readonly="readonly" type="checkbox" value="1" />), check_box_tag("admin", 1, true, 'disabled' => true, :readonly => "yes")
    assert_dom_equal %(<input checked="checked" id="admin" name="admin" type="checkbox" value="1" />), check_box_tag("admin", 1, true, :disabled => false, :readonly => nil)
    assert_dom_equal %(<select id="people" multiple="multiple" name="people"><option>david</option></select>), select_tag("people", "<option>david</option>", :multiple => true)
    assert_dom_equal %(<select id="people" name="people"><option>david</option></select>), select_tag("people", "<option>david</option>", :multiple => nil)
  end

  def test_stringify_symbol_keys
    actual = text_field_tag "title", "Hello!", :id => "admin"
    expected = %(<input id="admin" name="title" type="text" value="Hello!" />)
    assert_dom_equal expected, actual
  end
end

