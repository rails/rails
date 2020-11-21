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

  def test_dom_ids_with_argument_prefixes
    @record.save
    assert_equal "#{@singular}_1 edit_#{@singular}_1 delete_#{@singular}_1", dom_ids(@record, nil, :edit, :delete, new: !@record.persisted?)
  end

  def test_dom_ids_with_array_prefixes
    @record.save
    assert_equal "#{@singular}_1 edit_#{@singular}_1 delete_#{@singular}_1", dom_ids(@record, [nil, :edit, { new: !@record.persisted? }, :delete])
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
    @record = Plane.new
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

  def test_dom_ids_with_argument_prefixes
    @record.save
    assert_equal "airplane_1 custom_airplane_1 edit_airplane_1", dom_ids(@record, nil, :custom, :edit, new: false)
  end

  def test_dom_ids_with_array_prefixes
    @record.save
    assert_equal "airplane_1 custom_airplane_1 edit_airplane_1", dom_ids(@record, nil, [:custom, { new: false }, :edit])
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
