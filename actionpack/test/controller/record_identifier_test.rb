require 'abstract_unit'

class Comment
  attr_reader :id
  def save; @id = 1 end
  def new_record?; @id.nil? end
  def name
    @id.nil? ? 'new comment' : "comment ##{@id}"
  end
end

class Comment::Nested < Comment; end

class Test::Unit::TestCase
  protected
    def comments_url
      'http://www.example.com/comments'
    end
    
    def comment_url(comment)
      "http://www.example.com/comments/#{comment.id}"
    end
end


class RecordIdentifierTest < Test::Unit::TestCase
  include ActionController::RecordIdentifier

  def setup
    @klass  = Comment
    @record = @klass.new
    @singular = 'comment'
    @plural = 'comments'
  end

  def test_dom_id_with_new_record
    assert_equal "new_#{@singular}", dom_id(@record)
  end

  def test_dom_id_with_new_record_and_prefix
    assert_equal "custom_prefix_#{@singular}", dom_id(@record, :custom_prefix)
  end

  def test_dom_id_with_saved_record
    @record.save
    assert_equal "#{@singular}_1", dom_id(@record)
  end

  def test_dom_id_with_prefix
    @record.save
    assert_equal "edit_#{@singular}_1", dom_id(@record, :edit)
  end

  def test_partial_path
    expected = "#{@plural}/#{@singular}"
    assert_equal expected, partial_path(@record)
    assert_equal expected, partial_path(Comment)
  end

  def test_partial_path_with_namespaced_controller_path
    expected = "admin/#{@plural}/#{@singular}"
    assert_equal expected, partial_path(@record, "admin/posts")
    assert_equal expected, partial_path(@klass, "admin/posts")
  end

  def test_partial_path_with_not_namespaced_controller_path
    expected = "#{@plural}/#{@singular}"
    assert_equal expected, partial_path(@record, "posts")
    assert_equal expected, partial_path(@klass, "posts")
  end

  def test_dom_class
    assert_equal @singular, dom_class(@record)
  end
  
  def test_dom_class_with_prefix
    assert_equal "custom_prefix_#{@singular}", dom_class(@record, :custom_prefix)
  end

  def test_singular_class_name
    assert_equal @singular, singular_class_name(@record)
  end

  def test_singular_class_name_for_class
    assert_equal @singular, singular_class_name(@klass)
  end

  def test_plural_class_name
    assert_equal @plural, plural_class_name(@record)
  end

  def test_plural_class_name_for_class
    assert_equal @plural, plural_class_name(@klass)
  end

  private
    def method_missing(method, *args)
      RecordIdentifier.send(method, *args)
    end
end

class NestedRecordIdentifierTest < RecordIdentifierTest
  def setup
    @klass  = Comment::Nested
    @record = @klass.new
    @singular = 'comment_nested'
    @plural = 'comment_nesteds'
  end

  def test_partial_path
    expected = "comment/nesteds/nested"
    assert_equal expected, partial_path(@record)
    assert_equal expected, partial_path(Comment::Nested)
  end

  def test_partial_path_with_namespaced_controller_path
    expected = "admin/comment/nesteds/nested"
    assert_equal expected, partial_path(@record, "admin/posts")
    assert_equal expected, partial_path(@klass, "admin/posts")
  end

  def test_partial_path_with_deeper_namespaced_controller_path
    expected = "deeper/admin/comment/nesteds/nested"
    assert_equal expected, partial_path(@record, "deeper/admin/posts")
    assert_equal expected, partial_path(@klass, "deeper/admin/posts")
  end

  def test_partial_path_with_even_deeper_namespaced_controller_path
    expected = "even/more/deeper/admin/comment/nesteds/nested"
    assert_equal expected, partial_path(@record, "even/more/deeper/admin/posts")
    assert_equal expected, partial_path(@klass, "even/more/deeper/admin/posts")
  end

  def test_partial_path_with_not_namespaced_controller_path
    expected = "comment/nesteds/nested"
    assert_equal expected, partial_path(@record, "posts")
    assert_equal expected, partial_path(@klass, "posts")
  end
end
