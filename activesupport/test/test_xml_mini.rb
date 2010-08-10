require 'abstract_unit'
require 'active_support/xml_mini'

class XmlMiniTest < Test::Unit::TestCase
  def test_rename_key_dasherizes_by_default
    assert_equal "my-key", ActiveSupport::XmlMini.rename_key("my_key")
  end

  def test_rename_key_does_nothing_with_dasherize_true
    assert_equal "my-key", ActiveSupport::XmlMini.rename_key("my_key", :dasherize => true)
  end

  def test_rename_key_does_nothing_with_dasherize_false
    assert_equal "my_key", ActiveSupport::XmlMini.rename_key("my_key", :dasherize => false)
  end

  def test_rename_key_camelizes_with_camelize_true
    assert_equal "MyKey", ActiveSupport::XmlMini.rename_key("my_key", :camelize => true)
  end

  def test_rename_key_camelizes_with_camelize_true
    assert_equal "MyKey", ActiveSupport::XmlMini.rename_key("my_key", :camelize => true)
  end

  def test_rename_key_does_not_dasherize_leading_underscores
    assert_equal "_id", ActiveSupport::XmlMini.rename_key("_id")
  end

  def test_rename_key_with_leading_underscore_dasherizes_interior_underscores
    assert_equal "_my-key", ActiveSupport::XmlMini.rename_key("_my_key")
  end

  def test_rename_key_does_not_dasherize_trailing_underscores
    assert_equal "id_", ActiveSupport::XmlMini.rename_key("id_")
  end

  def test_rename_key_with_trailing_underscore_dasherizes_interior_underscores
    assert_equal "my-key_", ActiveSupport::XmlMini.rename_key("my_key_")
  end

  def test_rename_key_does_not_dasherize_multiple_leading_underscores
    assert_equal "__id", ActiveSupport::XmlMini.rename_key("__id")
  end

  def test_rename_key_does_not_dasherize_multiple_leading_underscores
    assert_equal "id__", ActiveSupport::XmlMini.rename_key("id__")
  end

end
