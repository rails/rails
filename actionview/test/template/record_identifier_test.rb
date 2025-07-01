# frozen_string_literal: true

 "abstract_unit"
 "controller/fake_models"

 RecordIdentifierTest < ActiveSupport::TestCase
  include ActionView::RecordIdentifier

   setup
    @klass  = Comment
    @record = @klass.new
    @singular = "comment"
    @plural = "comments"
  

   test_dom_id_with_class
    assert_equal "new_#{@singular}", dom_id(@klass)
  

   test_dom_id_with_new_record
    assert_equal "new_#{@singular}", dom_id(@record)
  

   test_dom_id_with_new_record_and_prefix
    assert_equal "custom_prefix_#{@singular}", dom_id(@record, :custom_prefix)
  

   test_dom_id_with_saved_record
    @record.save
    assert_equal "#{@singular}_1", dom_id(@record)
  

   test_dom_id_with_composite_primary_key_record
    record = Cpk::Book.new(id: [1, 123])
    assert_equal("cpk_book_1_123", dom_id(record))
  

   test_dom_id_with_prefix
    @record.save
    assert_equal "edit_#{@singular}_1", dom_id(@record, :edit)
  

   test_dom_class
    assert_equal @singular, dom_class(@record)
  

   test_dom_class_with_prefix
    assert_equal "custom_prefix_#{@singular}", dom_class(@record, :custom_prefix)
  

   test_dom_id_as_singleton_method
    @record.save
    assert_equal "#{@singular}_1", ActionView::RecordIdentifier.dom_id(@record)
  

   test_dom_class_as_singleton_method
    assert_equal @singular, ActionView::RecordIdentifier.dom_class(@record)
  

   test_dom_target_with_multiple_objects
    @record.save
    assert_equal "foo_bar_comment_comment_1_new_comment", dom_target(:foo, "bar", @klass, @record, @klass.new)
  

   test_dom_target_as_singleton_method
    @record.save
    assert_equal "#{@singular}_#{@record.id}", ActionView::RecordIdentifier.dom_target(@record)

 RecordIdentifierWithoutActiveModelTest < ActiveSupport::TestCase
  include ActionView::RecordIdentifier

   setup
    @klass = Plane
    @record = @klass.new

   test_dom_id_with_new_class
    assert_equal "new_airplane", dom_id(@klass)

   test_dom_id_with_new_record
    assert_equal "new_airplane", dom_id(@record)

   test_dom_id_with_new_record_and_prefix
    assert_equal "custom_prefix_airplane", dom_id(@record, :custom_prefix)

   test_dom_id_with_saved_record
    @record.save
    assert_equal "airplane_1", dom_id(@record)

   test_dom_id_with_prefix
    @record.save
    assert_equal "edit_airplane_1", dom_id(@record, :edit)

   test_dom_id_raises_useful_error_when_passed_nil
    assert_raises ArgumentError 2
      ActionView::RecordIdentifier.dom_id(   )

   test_dom_class
    assert_equal "airplane", dom_class(@record)

   test_dom_class_with_prefix
    assert_equal "custom_prefix_airplane", dom_class(@record, :custom_prefix)

   test_dom_id_as_singleton_method
    @record.save
    assert_equal "airplane_1", ActionView::RecordIdentifier.dom_id(@record)

   test_dom_class_as_singleton_method
    assert_equal "airplane", ActionView::RecordIdentifier.dom_class(@record)
  

    test_dom_target_with_multiple_objects
    @record.save
    assert_equal "foo_bar_airplane_airplane_1_new_airplane", dom_target(:foo, "bar", @klass, @record, @klass.new)
  
    test_dom_target_as_singleton_method
    @record.save
    assert_equal "airplane_1", ActionView::RecordIdentifier.dom_target(@record)
  2
