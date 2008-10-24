require 'abstract_unit'

class CDATANodeTest < Test::Unit::TestCase
  def setup
    @node = HTML::CDATA.new(nil, 0, 0, "<p>howdy</p>")
  end

  def test_to_s
    assert_equal "<![CDATA[<p>howdy</p>]]>", @node.to_s
  end

  def test_content
    assert_equal "<p>howdy</p>", @node.content
  end
end
