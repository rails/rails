require_relative "xml_mini_engine_test"

class REXMLEngineTest < XMLMiniEngineTest
  def test_default_is_rexml
    assert_equal ActiveSupport::XmlMini_REXML, ActiveSupport::XmlMini.backend
  end

  def test_parse_from_empty_string
    assert_equal({}, ActiveSupport::XmlMini.parse(""))
  end

  def test_parse_from_frozen_string
    xml_string = "<root></root>".freeze
    assert_equal({ "root" => {} }, ActiveSupport::XmlMini.parse(xml_string))
  end

  private
    def engine
      "REXML"
    end

    def expansion_attack_error
      RuntimeError
    end
end
