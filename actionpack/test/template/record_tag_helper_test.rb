require 'abstract_unit'
require 'controller/fake_models'

class RecordTagPost
  extend ActiveModel::Naming
  include ActiveModel::Conversion
  attr_writer :id, :body, :persisted

  def initialize
    @id = nil
    @body = nil
    @persisted = false
  end

  def id
     @id || 45
  end

  def body
    @body || "What a wonderful world!"
  end

  def persisted?; @persisted end

end

class RecordTagHelperTest < ActionView::TestCase
  include RenderERBUtils

  tests ActionView::Helpers::RecordTagHelper

  def setup
    super
    @post = RecordTagPost.new
    @post.persisted = true
  end

  def test_content_tag_for
    expected = %(<li class="record_tag_post bar" id="record_tag_post_45"></li>)
    actual = content_tag_for(:li, @post, :class => 'bar') { }
    assert_dom_equal expected, actual
  end

  def test_content_tag_for_prefix
    expected = %(<ul class="archived_record_tag_post" id="archived_record_tag_post_45"></ul>)
    actual = content_tag_for(:ul, @post, :archived) { }
    assert_dom_equal expected, actual
  end

  def test_content_tag_for_with_extra_html_tags
    expected = %(<tr class="record_tag_post bar" id="record_tag_post_45" style='background-color: #f0f0f0'></tr>)
    actual = content_tag_for(:tr, @post, {:class => "bar", :style => "background-color: #f0f0f0"}) { }
    assert_dom_equal expected, actual
  end

  def test_block_not_in_erb_multiple_calls
    expected = %(<div class="record_tag_post bar" id="record_tag_post_45">#{@post.body}</div>)
    actual = div_for(@post, :class => "bar") { @post.body }
    assert_dom_equal expected, actual
    actual = div_for(@post, :class => "bar") { @post.body }
    assert_dom_equal expected, actual
  end

  def test_block_works_with_content_tag_for_in_erb
    expected = %(<tr class="record_tag_post" id="record_tag_post_45">#{@post.body}</tr>)
    actual = render_erb("<%= content_tag_for(:tr, @post) do %><%= @post.body %><% end %>")
    assert_dom_equal expected, actual
  end

  def test_div_for_in_erb
    expected = %(<div class="record_tag_post bar" id="record_tag_post_45">#{@post.body}</div>)
    actual = render_erb("<%= div_for(@post, :class => 'bar') do %><%= @post.body %><% end %>")
    assert_dom_equal expected, actual
  end

  def test_content_tag_for_collection
    post_1 = RecordTagPost.new.tap { |post| post.id = 101; post.body = "Hello!"; post.persisted = true }
    post_2 = RecordTagPost.new.tap { |post| post.id = 102; post.body = "World!"; post.persisted = true }
    expected = %(<li class="record_tag_post" id="record_tag_post_101">Hello!</li>\n<li class="record_tag_post" id="record_tag_post_102">World!</li>)
    actual = content_tag_for(:li, [post_1, post_2]) { |post| concat post.body }
    assert_dom_equal expected, actual
  end

  def test_content_tag_for_collection_without_given_block
    post_1 = RecordTagPost.new.tap { |post| post.id = 101; post.body = "Hello!"; post.persisted = true }
    post_2 = RecordTagPost.new.tap { |post| post.id = 102; post.body = "World!"; post.persisted = true }
    expected = %(<li class="record_tag_post" id="record_tag_post_101"></li>\n<li class="record_tag_post" id="record_tag_post_102"></li>)
    actual = content_tag_for(:li, [post_1, post_2])
    assert_dom_equal expected, actual
  end

  def test_div_for_collection
    post_1 = RecordTagPost.new.tap { |post| post.id = 101; post.body = "Hello!"; post.persisted = true }
    post_2 = RecordTagPost.new.tap { |post| post.id = 102; post.body = "World!"; post.persisted = true }
    expected = %(<div class="record_tag_post" id="record_tag_post_101">Hello!</div>\n<div class="record_tag_post" id="record_tag_post_102">World!</div>)
    actual = div_for([post_1, post_2]) { |post| concat post.body }
    assert_dom_equal expected, actual
  end

  def test_content_tag_for_single_record_is_html_safe
    result = div_for(@post, :class => "bar") { concat @post.body }
    assert result.html_safe?
  end

  def test_content_tag_for_collection_is_html_safe
    post_1 = RecordTagPost.new.tap { |post| post.id = 101; post.body = "Hello!"; post.persisted = true }
    post_2 = RecordTagPost.new.tap { |post| post.id = 102; post.body = "World!"; post.persisted = true }
    result = content_tag_for(:li, [post_1, post_2]) { |post| concat post.body }
    assert result.html_safe?
  end

  def test_content_tag_for_does_not_change_options_hash
    options = { :class => "important" }
    content_tag_for(:li, @post, options) { }
    assert_equal({ :class => "important" }, options)
  end
end
