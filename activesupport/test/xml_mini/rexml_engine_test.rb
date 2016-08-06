require "abstract_unit"
require "active_support/xml_mini"

class REXMLEngineTest < ActiveSupport::TestCase
  def test_default_is_rexml
    assert_equal ActiveSupport::XmlMini_REXML, ActiveSupport::XmlMini.backend
  end

  def test_set_rexml_as_backend
    ActiveSupport::XmlMini.backend = "REXML"
    assert_equal ActiveSupport::XmlMini_REXML, ActiveSupport::XmlMini.backend
  end

  def test_parse_from_io
    ActiveSupport::XmlMini.backend = "REXML"
    io = StringIO.new(<<-eoxml)
    <root>
      good
      <products>
        hello everyone
      </products>
      morning
    </root>
    eoxml
    hash = ActiveSupport::XmlMini.parse(io)
    assert hash.has_key?("root")
    assert hash["root"].has_key?("products")
    assert_match "good", hash["root"]["__content__"]
    products = hash["root"]["products"]    
    assert products.has_key?("__content__")    
    assert_match "hello everyone", products["__content__"]
  end

  def test_parse_from_empty_string
    ActiveSupport::XmlMini.backend = "REXML"
    assert_equal({}, ActiveSupport::XmlMini.parse(""))
  end

  def test_parse_from_frozen_string
    ActiveSupport::XmlMini.backend = "REXML"
    xml_string = "<root></root>".freeze
    assert_equal({"root" => {}}, ActiveSupport::XmlMini.parse(xml_string))
  end

end
