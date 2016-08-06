if RUBY_PLATFORM.include?("java")
  require "abstract_unit"
  require "active_support/xml_mini"
  require "active_support/core_ext/hash/conversions"


  class JDOMEngineTest < ActiveSupport::TestCase
    include ActiveSupport

    FILES_DIR = File.dirname(__FILE__) + "/../fixtures/xml"

    def setup
      @default_backend = XmlMini.backend
      XmlMini.backend = "JDOM"
    end

    def teardown
      XmlMini.backend = @default_backend
    end

    def test_file_from_xml
      hash = Hash.from_xml(<<-eoxml)
         <blog>
           <logo type="file" name="logo.png" content_type="image/png">
           </logo>
         </blog>
       eoxml
      assert hash.has_key?("blog")
      assert hash["blog"].has_key?("logo")

      file = hash["blog"]["logo"]
      assert_equal "logo.png", file.original_filename
      assert_equal "image/png", file.content_type
    end

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

    def test_exception_thrown_on_expansion_attack
      assert_raise Java::OrgXmlSax::SAXParseException do
        attack_xml = <<-EOT
      <!DOCTYPE member [
        <!ENTITY a "&b;&b;&b;&b;&b;&b;&b;&b;&b;&b;">
        <!ENTITY b "&c;&c;&c;&c;&c;&c;&c;&c;&c;&c;">
        <!ENTITY c "&d;&d;&d;&d;&d;&d;&d;&d;&d;&d;">
        <!ENTITY d "&e;&e;&e;&e;&e;&e;&e;&e;&e;&e;">
        <!ENTITY e "&f;&f;&f;&f;&f;&f;&f;&f;&f;&f;">
        <!ENTITY f "&g;&g;&g;&g;&g;&g;&g;&g;&g;&g;">
        <!ENTITY g "xxxxxxxxxxxxxxxxxxxxxxxxxxxxxx">
      ]>
      <member>
      &a;
      </member>
        EOT
        Hash.from_xml(attack_xml)
      end
    end

    def test_setting_JDOM_as_backend
      XmlMini.backend = "JDOM"
      assert_equal XmlMini_JDOM, XmlMini.backend
    end

    def test_blank_returns_empty_hash
      assert_equal({}, XmlMini.parse(nil))
      assert_equal({}, XmlMini.parse(""))
    end

    def test_array_type_makes_an_array
      assert_equal_rexml(<<-eoxml)
      <blog>
        <posts type="array">
          <post>a post</post>
          <post>another post</post>
        </posts>
      </blog>
      eoxml
    end

    def test_one_node_document_as_hash
      assert_equal_rexml(<<-eoxml)
    <products/>
      eoxml
    end

    def test_one_node_with_attributes_document_as_hash
      assert_equal_rexml(<<-eoxml)
    <products foo="bar"/>
      eoxml
    end

    def test_products_node_with_book_node_as_hash
      assert_equal_rexml(<<-eoxml)
    <products>
      <book name="awesome" id="12345" />
    </products>
      eoxml
    end

    def test_products_node_with_two_book_nodes_as_hash
      assert_equal_rexml(<<-eoxml)
    <products>
      <book name="awesome" id="12345" />
      <book name="america" id="67890" />
    </products>
      eoxml
    end

    def test_single_node_with_content_as_hash
      assert_equal_rexml(<<-eoxml)
      <products>
        hello world
      </products>
      eoxml
    end

    def test_children_with_children
      assert_equal_rexml(<<-eoxml)
    <root>
      <products>
        <book name="america" id="67890" />
      </products>
    </root>
      eoxml
    end

    def test_children_with_text
      assert_equal_rexml(<<-eoxml)
    <root>
      <products>
        hello everyone
      </products>
    </root>
      eoxml
    end

    def test_children_with_non_adjacent_text
      assert_equal_rexml(<<-eoxml)
    <root>
      good
      <products>
        hello everyone
      </products>
      morning
    </root>
      eoxml
    end

    private
      def assert_equal_rexml(xml)
        parsed_xml = XmlMini.parse(xml)
        hash = XmlMini.with_backend("REXML") { XmlMini.parse(xml) }
        assert_equal(hash, parsed_xml)
      end
  end

else
  # don't run these test because we aren't running in JRuby
end
