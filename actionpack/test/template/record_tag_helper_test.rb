require 'abstract_unit'

class RecordTagPost
  extend ActiveModel::Naming
  include ActiveModel::Conversion
  attr_accessor :id, :body

  def initialize
    @id   = 45
    @body = "What a wonderful world!"

    yield self if block_given?
  end
end

class RecordTagHelperTest < ActionView::TestCase
  include RenderERBUtils

  tests ActionView::Helpers::RecordTagHelper

  def setup
    super
    @post = RecordTagPost.new
  end

  def test_content_tag_for
    expected = %(<li class="record_tag_post" id="record_tag_post_45"></li>)
    actual = content_tag_for(:li, @post)
    assert_dom_equal expected, actual
  end

  def test_content_tag_for_prefix
    expected = %(<ul class="archived_record_tag_post" id="archived_record_tag_post_45"></ul>)
    actual = content_tag_for(:ul, @post, :archived)
    assert_dom_equal expected, actual
  end

  def test_content_tag_for_with_extra_html_options
    expected = %(<tr class="record_tag_post special" id="record_tag_post_45" style='background-color: #f0f0f0'></tr>)
    actual = content_tag_for(:tr, @post, class: "special", style: "background-color: #f0f0f0")
    assert_dom_equal expected, actual
  end

  def test_content_tag_for_with_prefix_and_extra_html_options
    expected = %(<tr class="archived_record_tag_post special" id="archived_record_tag_post_45" style='background-color: #f0f0f0'></tr>)
    actual = content_tag_for(:tr, @post, :archived, class: "special", style: "background-color: #f0f0f0")
    assert_dom_equal expected, actual
  end

  def test_block_not_in_erb_multiple_calls
    expected = %(<div class="record_tag_post special" id="record_tag_post_45">What a wonderful world!</div>)
    actual = div_for(@post, class: "special") { @post.body }
    assert_dom_equal expected, actual
    actual = div_for(@post, class: "special") { @post.body }
    assert_dom_equal expected, actual
  end

  def test_block_works_with_content_tag_for_in_erb
    expected = %(<tr class="record_tag_post" id="record_tag_post_45">What a wonderful world!</tr>)
    actual = render_erb("<%= content_tag_for(:tr, @post) do %><%= @post.body %><% end %>")
    assert_dom_equal expected, actual
  end

  def test_div_for_in_erb
    expected = %(<div class="record_tag_post special" id="record_tag_post_45">What a wonderful world!</div>)
    actual = render_erb("<%= div_for(@post, class: 'special') do %><%= @post.body %><% end %>")
    assert_dom_equal expected, actual
  end

  def test_content_tag_for_collection
    post_1 = RecordTagPost.new { |post| post.id = 101; post.body = "Hello!" }
    post_2 = RecordTagPost.new { |post| post.id = 102; post.body = "World!" }
    expected = %(<li class="record_tag_post" id="record_tag_post_101">Hello!</li>\n<li class="record_tag_post" id="record_tag_post_102">World!</li>)
    actual = content_tag_for(:li, [post_1, post_2]) { |post| post.body }
    assert_dom_equal expected, actual
  end

  def test_content_tag_for_collection_without_given_block
    post_1 = RecordTagPost.new.tap { |post| post.id = 101; post.body = "Hello!" }
    post_2 = RecordTagPost.new.tap { |post| post.id = 102; post.body = "World!" }
    expected = %(<li class="record_tag_post" id="record_tag_post_101"></li>\n<li class="record_tag_post" id="record_tag_post_102"></li>)
    actual = content_tag_for(:li, [post_1, post_2])
    assert_dom_equal expected, actual
  end

  def test_div_for_collection
    post_1 = RecordTagPost.new { |post| post.id = 101; post.body = "Hello!" }
    post_2 = RecordTagPost.new { |post| post.id = 102; post.body = "World!" }
    expected = %(<div class="record_tag_post" id="record_tag_post_101">Hello!</div>\n<div class="record_tag_post" id="record_tag_post_102">World!</div>)
    actual = div_for([post_1, post_2]) { |post| post.body }
    assert_dom_equal expected, actual
  end

  def test_content_tag_for_single_record_is_html_safe
    result = div_for(@post, class: "special") { @post.body }
    assert result.html_safe?
  end

  def test_content_tag_for_collection_is_html_safe
    post_1 = RecordTagPost.new { |post| post.id = 101; post.body = "Hello!" }
    post_2 = RecordTagPost.new { |post| post.id = 102; post.body = "World!" }
    result = content_tag_for(:li, [post_1, post_2]) { |post| post.body }
    assert result.html_safe?
  end

  def test_content_tag_for_does_not_change_options_hash
    options = { class: "important" }
    content_tag_for(:li, @post, options)
    assert_equal({ class: "important" }, options)
  end
end
