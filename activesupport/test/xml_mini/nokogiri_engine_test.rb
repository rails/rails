require 'abstract_unit'
require 'active_support/xml_mini'

begin
  gem 'nokogiri', '>= 1.1.1'
rescue Gem::LoadError
  # Skip nokogiri tests
else

require 'nokogiri'

class NokogiriEngineTest < Test::Unit::TestCase
  include ActiveSupport

  def setup
    @default_backend = XmlMini.backend
    XmlMini.backend = 'Nokogiri'
  end

  def teardown
    XmlMini.backend = @default_backend
  end

  def test_setting_nokogiri_as_backend
    XmlMini.backend = 'Nokogiri'
    assert_equal XmlMini_Nokogiri, XmlMini.backend
  end

  def test_blank_returns_empty_hash
    assert_equal({}, XmlMini.parse(nil))
    assert_equal({}, XmlMini.parse(''))
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
    hash = XmlMini.with_backend('REXML') { XmlMini.parse(xml) }
    assert_equal(hash, XmlMini.parse(xml))
  end
end

end
