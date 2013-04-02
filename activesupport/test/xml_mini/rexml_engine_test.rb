require 'abstract_unit'
require 'active_support/xml_mini'

class REXMLEngineTest < ActiveSupport::TestCase
  include ActiveSupport

  def test_default_is_rexml
    assert_equal XmlMini_REXML, XmlMini.backend
  end

  def test_set_rexml_as_backend
    XmlMini.backend = 'REXML'
    assert_equal XmlMini_REXML, XmlMini.backend
  end

  def test_parse_from_io
    XmlMini.backend = 'REXML'
    io = StringIO.new(<<-eoxml)
    <root>
      good
      <products>
        hello everyone
      </products>
      morning
    </root>
    eoxml
    assert_equal_rexml(io)
  end

  private
    def assert_equal_rexml(xml)
      parsed_xml = XmlMini.parse(xml)
      hash = XmlMini.with_backend('REXML') { parsed_xml }
      assert_equal(hash, parsed_xml)
    end
end
