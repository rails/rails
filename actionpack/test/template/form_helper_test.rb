require 'test/unit'
require 'erb'
require File.dirname(__FILE__) + '/../../lib/action_view/helpers/form_helper'
require File.dirname(__FILE__) + '/../../../activesupport/lib/active_support/core_ext/hash' #for stringify keys

class FormHelperTest < Test::Unit::TestCase
  include ActionView::Helpers::FormHelper

  old_verbose, $VERBOSE = $VERBOSE, nil
  Post = Struct.new("Post", :title, :author_name, :body, :secret, :written_on, :cost)
  Post.class_eval do
    alias_method :title_before_type_cast, :title unless respond_to?(:title_before_type_cast)
    alias_method :body_before_type_cast, :body unless respond_to?(:body_before_type_cast)
    alias_method :author_name_before_type_cast, :author_name unless respond_to?(:author_name_before_type_cast)
  end
  $VERBOSE = old_verbose

  def setup
    @post = Post.new
    def @post.errors() Class.new{ def on(field) field == "author_name" end }.new end

    def @post.id; 123; end
    def @post.id_before_type_cast; 123; end

    @post.title       = "Hello World"
    @post.author_name = ""
    @post.body        = "Back to the hill and over it again!"
    @post.secret      = 1
    @post.written_on  = Date.new(2004, 6, 15)
  end

  def test_text_field
    assert_equal(
      '<input id="post_title" name="post[title]" size="30" type="text" value="Hello World" />', text_field("post", "title")
    )
    assert_equal(
      '<input id="post_title" name="post[title]" size="30" type="password" value="Hello World" />', password_field("post", "title")
    )
    assert_equal(
      '<input id="person_name" name="person[name]" size="30" type="password" />', password_field("person", "name")
    )
  end

  def test_text_field_with_escapes
    @post.title = "<b>Hello World</b>"
    assert_equal(
      '<input id="post_title" name="post[title]" size="30" type="text" value="&lt;b&gt;Hello World&lt;/b&gt;" />', text_field("post", "title")
    )
  end

  def test_text_field_with_options
    expected = '<input id="post_title" name="post[title]" size="35" type="text" value="Hello World" />'
    assert_equal expected, text_field("post", "title", "size" => 35)
    assert_equal expected, text_field("post", "title", :size => 35)
  end

  def test_text_field_assuming_size
    expected = '<input id="post_title" maxlength="35" name="post[title]" size="35" type="text" value="Hello World" />'
    assert_equal expected, text_field("post", "title", "maxlength" => 35)
    assert_equal expected, text_field("post", "title", :maxlength => 35)
  end

  def test_check_box
    assert_equal(
      '<input checked="checked" id="post_secret" name="post[secret]" type="checkbox" value="1" /><input name="post[secret]" type="hidden" value="0" />',
      check_box("post", "secret")
    )
    @post.secret = 0
    assert_equal(
      '<input id="post_secret" name="post[secret]" type="checkbox" value="1" /><input name="post[secret]" type="hidden" value="0" />',
      check_box("post", "secret")
    )
    assert_equal(
      '<input checked="checked" id="post_secret" name="post[secret]" type="checkbox" value="1" /><input name="post[secret]" type="hidden" value="0" />',
      check_box("post", "secret" ,{"checked"=>"checked"})
    )
    @post.secret = true
    assert_equal(
      '<input checked="checked" id="post_secret" name="post[secret]" type="checkbox" value="1" /><input name="post[secret]" type="hidden" value="0" />',
      check_box("post", "secret")
    )
  end

  def test_check_box_with_explicit_checked_and_unchecked_values
    @post.secret = "on"
    assert_equal(
      '<input checked="checked" id="post_secret" name="post[secret]" type="checkbox" value="on" /><input name="post[secret]" type="hidden" value="off" />',
      check_box("post", "secret", {}, "on", "off")
    )
  end

  def test_radio_button
    assert_equal('<input checked="checked" id="post_title_hello_world" name="post[title]" type="radio" value="Hello World" />',
      radio_button("post", "title", "Hello World")
    )
    assert_equal('<input id="post_title_goodbye_world" name="post[title]" type="radio" value="Goodbye World" />',
      radio_button("post", "title", "Goodbye World")
    )
  end

  def test_text_area
    assert_equal(
      '<textarea cols="40" id="post_body" name="post[body]" rows="20">Back to the hill and over it again!</textarea>',
      text_area("post", "body")
    )
  end

  def test_text_area_with_escapes
    @post.body        = "Back to <i>the</i> hill and over it again!"
    assert_equal(
      '<textarea cols="40" id="post_body" name="post[body]" rows="20">Back to &lt;i&gt;the&lt;/i&gt; hill and over it again!</textarea>',
      text_area("post", "body")
    )
  end

  def test_date_selects
    assert_equal(
      '<textarea cols="40" id="post_body" name="post[body]" rows="20">Back to the hill and over it again!</textarea>',
      text_area("post", "body")
    )
  end

  def test_explicit_name
    assert_equal(
      '<input id="post_title" name="dont guess" size="30" type="text" value="Hello World" />', text_field("post", "title", "name" => "dont guess")
    )
    assert_equal(
      '<textarea cols="40" id="post_body" name="really!" rows="20">Back to the hill and over it again!</textarea>',
      text_area("post", "body", "name" => "really!")
    )
    assert_equal(
      '<input checked="checked" id="post_secret" name="i mean it" type="checkbox" value="1" /><input name="i mean it" type="hidden" value="0" />',
      check_box("post", "secret", "name" => "i mean it")
    )
    assert_equal text_field("post", "title", "name" => "dont guess"),
                 text_field("post", "title", :name => "dont guess")
    assert_equal text_area("post", "body", "name" => "really!"),
                 text_area("post", "body", :name => "really!")
    assert_equal check_box("post", "secret", "name" => "i mean it"),
                 check_box("post", "secret", :name => "i mean it")
  end

  def test_explicit_id
    assert_equal(
      '<input id="dont guess" name="post[title]" size="30" type="text" value="Hello World" />', text_field("post", "title", "id" => "dont guess")
    )
    assert_equal(
      '<textarea cols="40" id="really!" name="post[body]" rows="20">Back to the hill and over it again!</textarea>',
      text_area("post", "body", "id" => "really!")
    )
    assert_equal(
      '<input checked="checked" id="i mean it" name="post[secret]" type="checkbox" value="1" /><input name="post[secret]" type="hidden" value="0" />',
      check_box("post", "secret", "id" => "i mean it")
    )
    assert_equal text_field("post", "title", "id" => "dont guess"),
                 text_field("post", "title", :id => "dont guess")
    assert_equal text_area("post", "body", "id" => "really!"),
                 text_area("post", "body", :id => "really!")
    assert_equal check_box("post", "secret", "id" => "i mean it"),
                 check_box("post", "secret", :id => "i mean it")
  end

  def test_auto_index
    pid = @post.id
    assert_equal(
      "<input id=\"post_#{pid}_title\" name=\"post[#{pid}][title]\" size=\"30\" type=\"text\" value=\"Hello World\" />", text_field("post[]","title")
    )
    assert_equal(
      "<textarea cols=\"40\" id=\"post_#{pid}_body\" name=\"post[#{pid}][body]\" rows=\"20\">Back to the hill and over it again!</textarea>",
      text_area("post[]", "body")
    )
    assert_equal(
      "<input checked=\"checked\" id=\"post_#{pid}_secret\" name=\"post[#{pid}][secret]\" type=\"checkbox\" value=\"1\" /><input name=\"post[#{pid}][secret]\" type=\"hidden\" value=\"0\" />",
      check_box("post[]", "secret")
    )
   assert_equal(
"<input checked=\"checked\" id=\"post_#{pid}_title_hello_world\" name=\"post[#{pid}][title]\" type=\"radio\" value=\"Hello World\" />",
      radio_button("post[]", "title", "Hello World")
    )
    assert_equal("<input id=\"post_#{pid}_title_goodbye_world\" name=\"post[#{pid}][title]\" type=\"radio\" value=\"Goodbye World\" />",
      radio_button("post[]", "title", "Goodbye World")
    )
  end
end
