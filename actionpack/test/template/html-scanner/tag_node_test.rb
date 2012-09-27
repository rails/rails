require 'abstract_unit'

class TagNodeTest < ActiveSupport::TestCase
  def test_open_without_attributes
    node = tag("<tag>")
    assert_equal "tag", node.name
    assert_equal Hash.new, node.attributes
    assert_nil node.closing
  end

  def test_open_with_attributes
    node = tag("<TAG1 foo=hey_ho x:bar=\"blah blah\" BAZ='blah blah blah' >")
    assert_equal "tag1", node.name
    assert_equal "hey_ho", node["foo"]
    assert_equal "blah blah", node["x:bar"]
    assert_equal "blah blah blah", node["baz"]
  end

  def test_self_closing_without_attributes
    node = tag("<tag/>")
    assert_equal "tag", node.name
    assert_equal Hash.new, node.attributes
    assert_equal :self, node.closing
  end

  def test_self_closing_with_attributes
    node = tag("<tag a=b/>")
    assert_equal "tag", node.name
    assert_equal( { "a" => "b" }, node.attributes )
    assert_equal :self, node.closing
  end

  def test_closing_without_attributes
    node = tag("</tag>")
    assert_equal "tag", node.name
    assert_nil node.attributes
    assert_equal :close, node.closing
  end

  def test_bracket_op_when_no_attributes
    node = tag("</tag>")
    assert_nil node["foo"]
  end

  def test_bracket_op_when_attributes
    node = tag("<tag a=b/>")
    assert_equal "b", node["a"]
  end

  def test_attributes_with_escaped_quotes
    node = tag("<tag a='b\\'c' b=\"bob \\\"float\\\"\">")
    assert_equal "b\\'c", node["a"]
    assert_equal "bob \\\"float\\\"", node["b"]
  end

  def test_to_s
    node = tag("<a b=c d='f' g=\"h 'i'\" />")
    node = node.to_s
    assert node.include?('a')
    assert node.include?('b="c"')
    assert node.include?('d="f"')
    assert node.include?('g="h')
    assert node.include?('i')
  end

  def test_tag
    assert tag("<tag>").tag?
  end

  def test_match_tag_as_string
    assert tag("<tag>").match(:tag => "tag")
    assert !tag("<tag>").match(:tag => "b")
  end

  def test_match_tag_as_regexp
    assert tag("<tag>").match(:tag => /t.g/)
    assert !tag("<tag>").match(:tag => /t[bqs]g/)
  end

  def test_match_attributes_as_string
    t = tag("<tag a=something b=else />")
    assert t.match(:attributes => {"a" => "something"})
    assert t.match(:attributes => {"b" => "else"})
  end

  def test_match_attributes_as_regexp
    t = tag("<tag a=something b=else />")
    assert t.match(:attributes => {"a" => /^something$/})
    assert t.match(:attributes => {"b" =>  /e.*e/})
    assert t.match(:attributes => {"a" => /me..i/, "b" => /.ls.$/})
  end

  def test_match_attributes_as_number
    t = tag("<tag a=15 b=3.1415 />")
    assert t.match(:attributes => {"a" => 15})
    assert t.match(:attributes => {"b" => 3.1415})
    assert t.match(:attributes => {"a" => 15, "b" => 3.1415})
  end

  def test_match_attributes_exist
    t = tag("<tag a=15 b=3.1415 />")
    assert t.match(:attributes => {"a" => true})
    assert t.match(:attributes => {"b" => true})
    assert t.match(:attributes => {"a" => true, "b" => true})
  end

  def test_match_attributes_not_exist
    t = tag("<tag a=15 b=3.1415 />")
    assert t.match(:attributes => {"c" => false})
    assert t.match(:attributes => {"c" => nil})
    assert t.match(:attributes => {"a" => true, "c" => false})
  end

  def test_match_parent_success
    t = tag("<tag a=15 b='hello'>", tag("<foo k='value'>"))
    assert t.match(:parent => {:tag => "foo", :attributes => {"k" => /v.l/, "j" => false}})
  end

  def test_match_parent_fail
    t = tag("<tag a=15 b='hello'>", tag("<foo k='value'>"))
    assert !t.match(:parent => {:tag => /kafka/})
  end

  def test_match_child_success
    t = tag("<tag x:k='something'>")
    tag("<child v=john a=kelly>", t)
    tag("<sib m=vaughn v=james>", t)
    assert t.match(:child => { :tag => "sib", :attributes => {"v" => /j/}})
    assert t.match(:child => { :attributes => {"a" => "kelly"}})
  end

  def test_match_child_fail
    t = tag("<tag x:k='something'>")
    tag("<child v=john a=kelly>", t)
    tag("<sib m=vaughn v=james>", t)
    assert !t.match(:child => { :tag => "sib", :attributes => {"v" => /r/}})
    assert !t.match(:child => { :attributes => {"v" => false}})
  end

  def test_match_ancestor_success
    t = tag("<tag x:k='something'>", tag("<parent v=john a=kelly>", tag("<grandparent m=vaughn v=james>")))
    assert t.match(:ancestor => {:tag => "parent", :attributes => {"a" => /ll/}})
    assert t.match(:ancestor => {:attributes => {"m" => "vaughn"}})
  end

  def test_match_ancestor_fail
    t = tag("<tag x:k='something'>", tag("<parent v=john a=kelly>", tag("<grandparent m=vaughn v=james>")))
    assert !t.match(:ancestor => {:tag => /^parent/, :attributes => {"v" => /m/}})
    assert !t.match(:ancestor => {:attributes => {"v" => false}})
  end

  def test_match_descendant_success
    tag("<grandchild m=vaughn v=james>", tag("<child v=john a=kelly>", t = tag("<tag x:k='something'>")))
    assert t.match(:descendant => {:tag => "child", :attributes => {"a" => /ll/}})
    assert t.match(:descendant => {:attributes => {"m" => "vaughn"}})
  end

  def test_match_descendant_fail
    tag("<grandchild m=vaughn v=james>", tag("<child v=john a=kelly>", t = tag("<tag x:k='something'>")))
    assert !t.match(:descendant => {:tag => /^child/, :attributes => {"v" => /m/}})
    assert !t.match(:descendant => {:attributes => {"v" => false}})
  end

  def test_match_child_count
    t = tag("<tag x:k='something'>")
    tag("hello", t)
    tag("<child v=john a=kelly>", t)
    tag("<sib m=vaughn v=james>", t)
    assert t.match(:children => { :count => 2 })
    assert t.match(:children => { :count => 2..4 })
    assert t.match(:children => { :less_than => 4 })
    assert t.match(:children => { :greater_than => 1 })
    assert !t.match(:children => { :count => 3 })
  end

  def test_conditions_as_strings
    t = tag("<tag x:k='something'>")
    assert t.match("tag" => "tag")
    assert t.match("attributes" => { "x:k" => "something" })
    assert !t.match("tag" => "gat")
    assert !t.match("attributes" => { "x:j" => "something" })
  end

  def test_attributes_as_symbols
    t = tag("<child v=john a=kelly>")
    assert t.match(:attributes => { :v => /oh/ })
    assert t.match(:attributes => { :a => /ll/ })
  end

  def test_match_sibling
    t = tag("<tag x:k='something'>")
    tag("hello", t)
    tag("<span a=b>", t)
    tag("world", t)
    m = tag("<span k=r>", t)
    tag("<span m=l>", t)

    assert m.match(:sibling => {:tag => "span", :attributes => {:a => true}})
    assert m.match(:sibling => {:tag => "span", :attributes => {:m => true}})
    assert !m.match(:sibling => {:tag => "span", :attributes => {:k => true}})
  end

  def test_match_sibling_before
    t = tag("<tag x:k='something'>")
    tag("hello", t)
    tag("<span a=b>", t)
    tag("world", t)
    m = tag("<span k=r>", t)
    tag("<span m=l>", t)

    assert m.match(:before => {:tag => "span", :attributes => {:m => true}})
    assert !m.match(:before => {:tag => "span", :attributes => {:a => true}})
    assert !m.match(:before => {:tag => "span", :attributes => {:k => true}})
  end

  def test_match_sibling_after
    t = tag("<tag x:k='something'>")
    tag("hello", t)
    tag("<span a=b>", t)
    tag("world", t)
    m = tag("<span k=r>", t)
    tag("<span m=l>", t)

    assert m.match(:after => {:tag => "span", :attributes => {:a => true}})
    assert !m.match(:after => {:tag => "span", :attributes => {:m => true}})
    assert !m.match(:after => {:tag => "span", :attributes => {:k => true}})
  end

  def test_tag_to_s
    t = tag("<b x='foo'>")
    tag("hello", t)
    tag("<hr />", t)
    assert_equal %(<b x="foo">hello<hr /></b>), t.to_s
  end

  private

    def tag(content, parent=nil)
      node = HTML::Node.parse(parent,0,0,content)
      parent.children << node if parent
      node
    end
end
