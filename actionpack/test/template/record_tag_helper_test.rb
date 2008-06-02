require 'abstract_unit'

class Post
  def id
     45 
  end
  def body
    "What a wonderful world!"
  end
end

class RecordTagHelperTest < ActionView::TestCase
  tests ActionView::Helpers::RecordTagHelper

  def setup
    @post = Post.new
  end
  
  def test_content_tag_for
    @output_buffer = ''
    expected = %(<li class="post bar" id="post_45"></li>)
    actual = content_tag_for(:li, @post, :class => 'bar') { }
    assert_dom_equal expected, actual
  end
  
  def test_content_tag_for_prefix
    @output_buffer = ''
    expected = %(<ul class="post" id="archived_post_45"></ul>)
    actual = content_tag_for(:ul, @post, :archived) { }
    assert_dom_equal expected, actual    
  end
  
  def test_content_tag_for_with_extra_html_tags
    @output_buffer = ''
    expected = %(<tr class="post bar" id="post_45" style='background-color: #f0f0f0'></tr>)
    actual = content_tag_for(:tr, @post, {:class => "bar", :style => "background-color: #f0f0f0"}) { }
    assert_dom_equal expected, actual        
  end
  
  def test_block_works_with_content_tag_for
    @output_buffer = ''
    expected = %(<tr class="post" id="post_45">#{@post.body}</tr>)
    actual = content_tag_for(:tr, @post) { @output_buffer.concat @post.body }
    assert_dom_equal expected, actual            
  end
  
  def test_div_for    
    @output_buffer = ''
    expected = %(<div class="post bar" id="post_45">#{@post.body}</div>)
    actual = div_for(@post, :class => "bar") { @output_buffer.concat @post.body }
    assert_dom_equal expected, actual
  end  
  
end
