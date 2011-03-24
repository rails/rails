require 'abstract_unit'

class ActiveModelHelperTest < ActionView::TestCase
  tests ActionView::Helpers::ActiveModelHelper

  silence_warnings do
    class Post < Struct.new(:author_name, :body)
      include ActiveModel::Conversion
      include ActiveModel::Validations

      def persisted?
        false
      end
    end
  end

  def setup
    super

    @post = Post.new
    @post.errors[:author_name] << "can't be empty"
    @post.errors[:body] << "foo"

    @post.author_name = ""
    @post.body        = "Back to the hill and over it again!"
  end

  def test_text_area_with_errors
    assert_dom_equal(
      %(<div class="field_with_errors"><textarea cols="40" id="post_body" name="post[body]" rows="20">Back to the hill and over it again!</textarea></div>),
      text_area("post", "body")
    )
  end

  def test_text_field_with_errors
    assert_dom_equal(
      %(<div class="field_with_errors"><input id="post_author_name" name="post[author_name]" size="30" type="text" value="" /></div>),
      text_field("post", "author_name")
    )
  end

  def test_hidden_field_does_not_render_errors
    assert_dom_equal(
      %(<input id="post_author_name" name="post[author_name]" type="hidden" value="" />),
      hidden_field("post", "author_name")
    )
  end

  def test_field_error_proc
    old_proc = ActionView::Base.field_error_proc
    ActionView::Base.field_error_proc = Proc.new do |html_tag, instance|
      %(<div class=\"field_with_errors\">#{html_tag} <span class="error">#{[instance.error_message].join(', ')}</span></div>).html_safe
    end

    assert_dom_equal(
      %(<div class="field_with_errors"><input id="post_author_name" name="post[author_name]" size="30" type="text" value="" /> <span class="error">can't be empty</span></div>),
      text_field("post", "author_name")
    )
  ensure
    ActionView::Base.field_error_proc = old_proc if old_proc
  end
end
