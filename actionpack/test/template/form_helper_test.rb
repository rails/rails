require 'test/unit'
require File.dirname(__FILE__) + '/../../lib/action_view/helpers/form_helper'

class FormHelperTest < Test::Unit::TestCase
  include ActionView::Helpers::FormHelper

  Post = Struct.new("Post", :title, :author_name, :body, :secret, :written_on)

  def setup
    @post = Post.new    
    def @post.errors() Class.new{ def on(field) field == "author_name" end }.new end

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
      '<input id="person_name" name="person[name]" size="30" type="password" value="" />', password_field("person", "name")
    )
  end
  
  def test_text_field_with_options
    assert_equal(
      '<input id="post_title" name="post[title]" size="35" type="text" value="Hello World" />', 
      text_field("post", "title", "size" => "35")
    )
  end
  
  def test_text_field_assuming_size
    assert_equal(
      '<input id="post_title" maxlength="35" name="post[title]" size="30" type="text" value="Hello World" />', 
      text_field("post", "title", "maxlength" => 35)
    )
  end
  
  def test_check_box
    assert_equal(
      '<input checked="checked" id="post_secret" name="post[secret]" type="checkbox" value="1" />', check_box("post", "secret")
    )

    @post.secret = 0
    assert_equal '<input id="post_secret" name="post[secret]" type="checkbox" value="1" />', check_box("post", "secret")    
  end
  
  def test_text_area
    assert_equal(
      '<textarea cols="40" id="post_body" name="post[body]" rows="20" wrap="virtual">Back to the hill and over it again!</textarea>',
      text_area("post", "body")
    )
  end
  
  def test_date_selects
    assert_equal(
      '<textarea cols="40" id="post_body" name="post[body]" rows="20" wrap="virtual">Back to the hill and over it again!</textarea>',
      text_area("post", "body")
    )
  end
end