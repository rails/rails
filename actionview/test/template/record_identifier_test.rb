# frozen_string_literal: true

require "abstract_unit"
require "controller/fake_models"

class RecordIdentifierTest < ActiveSupport::TestCase
  include ActionView::RecordIdentifier

  def setup
    @klass  = Comment
    @record = @klass.new
    @singular = "comment"
    @plural = "comments"
  end

  def test_dom_id_with_class
    assert_equal "new_#{@singular}", dom_id(@klass)
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

  def test_dom_id_with_composite_primary_key_record
    record = Cpk::Book.new(id: [1, 123])
    assert_equal("cpk_book_1_123", dom_id(record))
  end

  def test_dom_id_with_prefix
    @record.save
    assert_equal "edit_#{@singular}_1", dom_id(@record, :edit)
  end

  def test_dom_class
    assert_equal @singular, dom_class(@record)
  end

  def test_dom_class_with_prefix
    assert_equal "custom_prefix_#{@singular}", dom_class(@record, :custom_prefix)
  end

  def test_dom_id_as_singleton_method
    @record.save
    assert_equal "#{@singular}_1", ActionView::RecordIdentifier.dom_id(@record)
  end

  def test_dom_class_as_singleton_method
    assert_equal @singular, ActionView::RecordIdentifier.dom_class(@record)
  end
end

class RecordIdentifierWithoutActiveModelTest < ActiveSupport::TestCase
  include ActionView::RecordIdentifier

  def setup
    @klass = Plane
    @record = @klass.new
  end

  def test_dom_id_with_new_class
    assert_equal "new_airplane", dom_id(@klass)
  end

  def test_dom_id_with_new_record
    assert_equal "new_airplane", dom_id(@record)
  end

  def test_dom_id_with_new_record_and_prefix
    assert_equal "custom_prefix_airplane", dom_id(@record, :custom_prefix)
  end

  def test_dom_id_with_saved_record
    @record.save
    assert_equal "airplane_1", dom_id(@record)
  end

  def test_dom_id_with_prefix
    @record.save
    assert_equal "edit_airplane_1", dom_id(@record, :edit)
  end

  def test_dom_id_raises_useful_error_when_passed_nil
    assert_raises ArgumentError do
      ActionView::RecordIdentifier.dom_id(nil)
    end
  end

  def test_dom_class
    assert_equal "airplane", dom_class(@record)
  end

  def test_dom_class_with_prefix
    assert_equal "custom_prefix_airplane", dom_class(@record, :custom_prefix)
  end

  def test_dom_id_as_singleton_method
    @record.save
    assert_equal "airplane_1", ActionView::RecordIdentifier.dom_id(@record)
  end

  def test_dom_class_as_singleton_method
    assert_equal "airplane", ActionView::RecordIdentifier.dom_class(@record)
  end
end
