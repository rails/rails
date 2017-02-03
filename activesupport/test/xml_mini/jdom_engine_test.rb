require_relative "xml_mini_engine_test"

XMLMiniEngineTest.run_with_platform("java") do
  class JDOMEngineTest < XMLMiniEngineTest
    FILES_DIR = File.dirname(__FILE__) + "/../fixtures/xml"

    def test_not_allowed_to_expand_entities_to_files
      attack_xml = <<-EOT
      <!DOCTYPE member [
        <!ENTITY a SYSTEM "file://#{FILES_DIR}/jdom_include.txt">
      ]>
      <member>x&a;</member>
      EOT
      assert_equal "x", Hash.from_xml(attack_xml)["member"]
    end

    def test_not_allowed_to_expand_parameter_entities_to_files
      attack_xml = <<-EOT
      <!DOCTYPE member [
        <!ENTITY % b SYSTEM "file://#{FILES_DIR}/jdom_entities.txt">
        %b;
      ]>
      <member>x&a;</member>
      EOT
      assert_raise Java::OrgXmlSax::SAXParseException do
        assert_equal "x", Hash.from_xml(attack_xml)["member"]
      end
    end

    def test_not_allowed_to_load_external_doctypes
      attack_xml = <<-EOT
      <!DOCTYPE member SYSTEM "file://#{FILES_DIR}/jdom_doctype.dtd">
      <member>x&a;</member>
      EOT
      assert_equal "x", Hash.from_xml(attack_xml)["member"]
    end

    private
      def engine
        "JDOM"
      end

      def expansion_attack_error
        Java::OrgXmlSax::SAXParseException
      end

      def extended_engine?
        false
      end
  end
end
