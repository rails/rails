require 'abstract_unit'
require 'controller/fake_models'

class UnorderedListHelperTest < ActionView::TestCase
  def test_empty_unordered_list
    assert_dom_equal('<ul class="posts"></ul>', unordered_list(:posts))
  end
  
  def test_unordered_list_with_list_items
    posts = []
    posts << Post.new('First')
    assert_dom_equal('<ul class="posts"><li class="post">First</li></ul>', unordered_list(posts) { |post| post.title })
  end
  
  def test_unordered_list_with_data_attributes
    assert_dom_equal('<ul class="posts" data-url="/posts"></ul>', unordered_list(:posts, data: { url: '/posts' }))
  end
  
  def test_unordered_list_with_data_attributes_and_list_items
    posts = []
    posts << Post.new('First')

    expected = '<ul class="posts" data-url="/posts"><li class="post">First</li></ul>'
    actual = unordered_list(posts, data: { url: '/posts' }) { |post| post.title }
    assert_dom_equal(expected, actual)
  end
  
  def test_unordered_list_abbreviation
    assert_dom_equal('<ul class="posts"></ul>', ul(:posts))
  end
end
