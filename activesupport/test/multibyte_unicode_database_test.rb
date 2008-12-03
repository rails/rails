# encoding: utf-8
require 'abstract_unit'

class MultibyteUnicodeDatabaseTest < Test::Unit::TestCase
  def setup
    @ucd = ActiveSupport::Multibyte::UnicodeDatabase.new
  end

  ActiveSupport::Multibyte::UnicodeDatabase::ATTRIBUTES.each do |attribute|
    define_method "test_lazy_loading_on_attribute_access_of_#{attribute}" do
      @ucd.expects(:load)
      @ucd.send(attribute)
    end
  end
  
  def test_load
    @ucd.load
    ActiveSupport::Multibyte::UnicodeDatabase::ATTRIBUTES.each do |attribute|
      assert @ucd.send(attribute).length > 1
    end
  end
end
