require 'abstract_unit'
require 'active_support/xml_mini'

class REXMLEngineTest < ActiveSupport::TestCase
  def test_default_is_rexml
    assert_equal ActiveSupport::XmlMini_REXML, ActiveSupport::XmlMini.backend
  end

  def test_set_rexml_as_backend
    ActiveSupport::XmlMini.backend = 'REXML'
    assert_equal ActiveSupport::XmlMini_REXML, ActiveSupport::XmlMini.backend
  end

  def test_parse_from_io
    ActiveSupport::XmlMini.backend = 'REXML'
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
      parsed_xml = ActiveSupport::XmlMini.parse(xml)
      xml.rewind if xml.respond_to?(:rewind)
      hash = ActiveSupport::XmlMini.with_backend('REXML') { ActiveSupport::XmlMini.parse(xml) }
      assert_equal(hash, parsed_xml)
    end
end
