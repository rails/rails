require 'abstract_unit'
require 'controller/fake_models'

class ControllerRecordIdentifierTest < ActiveSupport::TestCase
  include ActionController::RecordIdentifier

  def setup
    @record = Comment.new
  end

  def test_dom_id_deprecation
    assert_deprecated(/dom_id method will no longer be included by default in controllers/) do
      dom_id(@record)
    end
  end

  def test_dom_class_deprecation
    assert_deprecated(/dom_class method will no longer be included by default in controllers/) do
      dom_class(@record)
    end
  end

  def test_dom_id_from_module_deprecation
    assert_deprecated(/Calling ActionController::RecordIdentifier.dom_id is deprecated/) do
      ActionController::RecordIdentifier.dom_id(@record)
    end
  end

  def test_dom_class_from_module_deprecation
    assert_deprecated(/Calling ActionController::RecordIdentifier.dom_class is deprecated/) do
      ActionController::RecordIdentifier.dom_class(@record)
    end
  end
end
