require 'abstract_unit'
require 'active_support/xml_mini'

class REXMLEngineTest < Test::Unit::TestCase
  include ActiveSupport

  def test_default_is_rexml
    assert_equal XmlMini_REXML, XmlMini.backend
  end

  def test_set_rexml_as_backend
    XmlMini.backend = 'REXML'
    assert_equal XmlMini_REXML, XmlMini.backend
  end
end
