require 'abstract_unit'

class NodeTest < Test::Unit::TestCase
  
  class MockNode
    def initialize(matched, value)
      @matched = matched
      @value = value
    end
    
    def find(conditions)
      @matched && self
    end
    
    def to_s
      @value.to_s
    end
  end
  
  def setup
    @node = HTML::Node.new("parent")
    @node.children.concat [MockNode.new(false,1), MockNode.new(true,"two"), MockNode.new(false,:three)]
  end
  
  def test_match
    assert !@node.match("foo")
  end
  
  def test_tag
    assert !@node.tag?
  end
  
  def test_to_s
    assert_equal "1twothree", @node.to_s
  end
  
  def test_find
    assert_equal "two", @node.find('blah').to_s
  end

  def test_parse_strict
    s = "<b foo='hello'' bar='baz'>"
    assert_raise(RuntimeError) { HTML::Node.parse(nil,0,0,s) }
  end

  def test_parse_relaxed
    s = "<b foo='hello'' bar='baz'>"
    node = nil
    assert_nothing_raised { node = HTML::Node.parse(nil,0,0,s,false) }
    assert node.attributes.has_key?("foo")
    assert !node.attributes.has_key?("bar")
  end

  def test_to_s_with_boolean_attrs
    s = "<b foo bar>"
    node = HTML::Node.parse(nil,0,0,s)
    assert node.attributes.has_key?("foo")
    assert node.attributes.has_key?("bar")
    assert "<b foo bar>", node.to_s
  end
  
  def test_parse_with_unclosed_tag
    s = "<span onmouseover='bang'"
    node = nil
    assert_nothing_raised { node = HTML::Node.parse(nil,0,0,s,false) }
    assert node.attributes.has_key?("onmouseover")
  end

  def test_parse_with_valid_cdata_section
    s = "<![CDATA[<span>contents</span>]]>"
    node = nil
    assert_nothing_raised { node = HTML::Node.parse(nil,0,0,s,false) }
    assert_kind_of HTML::CDATA, node
    assert_equal '<span>contents</span>', node.content
  end

  def test_parse_strict_with_unterminated_cdata_section
    s = "<![CDATA[neverending..."
    assert_raise(RuntimeError) { HTML::Node.parse(nil,0,0,s) }
  end

  def test_parse_relaxed_with_unterminated_cdata_section
    s = "<![CDATA[neverending..."
    node = nil
    assert_nothing_raised { node = HTML::Node.parse(nil,0,0,s,false) }
    assert_kind_of HTML::CDATA, node
    assert_equal 'neverending...', node.content
  end
end
