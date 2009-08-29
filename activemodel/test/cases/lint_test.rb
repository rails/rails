require "cases/helper"

class TestLint < Test::Unit::TestCase
  class CompliantObject
    def to_model
      self
    end
    
    def valid?()      true end
    def new_record?() true end
    def destroyed?()  true end
    
    def errors
      obj = Object.new
      def obj.[](key)         [] end
      def obj.full_messages() [] end
      obj
    end
  end
  
  def assert_output(object, failures, errors, *test_names)
    ActiveModel::Lint.test(object, 3, output = StringIO.new)
    regex =  %r{#{failures} failures, #{errors} errors}
    assert_match regex, output.string
    
    test_names.each do |test_name|
      assert_match test_name, output.string
    end
  end
  
  def test_valid
    assert_output(CompliantObject.new, 0, 0, /test_valid/)
  end
  
  def test_new_record
    assert_output(CompliantObject.new, 0, 0, /test_new_record?/)
  end
  
  def test_destroyed
    assert_output(CompliantObject.new, 0, 0, /test_destroyed/)
  end
  
  def test_errors_aref
    assert_output(CompliantObject.new, 0, 0, /test_errors_aref/)
  end

  def test_errors_full_messages
    assert_output(CompliantObject.new, 0, 0, /test_errors_aref/)
  end
end