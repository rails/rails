require 'abstract_unit'
require 'active_model'

class Bunny < Struct.new(:Bunny, :id)
  extend ActiveModel::Naming
  include ActiveModel::Conversion
  def to_key() id ? [id] : nil end
end

class Author
  extend ActiveModel::Naming
  include ActiveModel::Conversion

  attr_reader :id
  def to_key() id ? [id] : nil end
  def save; @id = 1 end
  def new_record?; @id.nil? end
  def name
    @id.nil? ? 'new author' : "author ##{@id}"
  end
end

class Article
  extend ActiveModel::Naming
  include ActiveModel::Conversion
  attr_reader :id
  attr_reader :author_id
  def to_key() id ? [id] : nil end
  def save; @id = 1; @author_id = 1 end
  def new_record?; @id.nil? end
  def name
    @id.nil? ? 'new article' : "article ##{@id}"
  end
end

class Author::Nested < Author; end


class PrototypeHelperBaseTest < ActionView::TestCase
  attr_accessor :formats, :output_buffer

  def update_details(details)
    @details = details
    yield if block_given?
  end

  def setup
    super
    @template = self
  end

  def url_for(options)
    if options.is_a?(String)
      options
    else
      url =  "http://www.example.com/"
      url << options[:action].to_s if options and options[:action]
      url << "?a=#{options[:a]}" if options && options[:a]
      url << "&b=#{options[:b]}" if options && options[:a] && options[:b]
      url
    end
  end

  protected
    def request_forgery_protection_token
      nil
    end

    def protect_against_forgery?
      false
    end

    def create_generator
      block = Proc.new { |*args| yield(*args) if block_given? }
      JavaScriptGenerator.new self, &block
    end
end

class PrototypeHelperTest < PrototypeHelperBaseTest
  def _evaluate_assigns_and_ivars() end

  def setup
    @record = @author = Author.new
    @article = Article.new
    super
  end

  def test_update_page
    old_output_buffer = output_buffer

    block = Proc.new { |page| page.replace_html('foo', 'bar') }
    assert_equal create_generator(&block).to_s, update_page(&block)

    assert_equal old_output_buffer, output_buffer
  end

  def test_update_page_tag
    block = Proc.new { |page| page.replace_html('foo', 'bar') }
    assert_equal javascript_tag(create_generator(&block).to_s), update_page_tag(&block)
  end

  def test_update_page_tag_with_html_options
    block = Proc.new { |page| page.replace_html('foo', 'bar') }
    assert_equal javascript_tag(create_generator(&block).to_s, {:defer => 'true'}), update_page_tag({:defer => 'true'}, &block)
  end

  def test_remote_function
    res = remote_function(:url => authors_path, :with => "'author[name]='+$F('author_name')+'&author[dob]='+$F('author_dob')")
    assert_equal "new Ajax.Request('/authors', {asynchronous:true, evalScripts:true, parameters:'author[name]='+$F('author_name')+'&author[dob]='+$F('author_dob')})", res
    assert res.html_safe?
  end

  protected
    def author_path(record)
      "/authors/#{record.id}"
    end

    def authors_path
      "/authors"
    end

    def author_articles_path(author)
      "/authors/#{author.id}/articles"
    end

    def author_article_path(author, article)
      "/authors/#{author.id}/articles/#{article.id}"
    end
end

class JavaScriptGeneratorTest < PrototypeHelperBaseTest
  def setup
    super
    @generator = create_generator
    ActiveSupport.escape_html_entities_in_json  = true
  end

  def teardown
    ActiveSupport.escape_html_entities_in_json  = false
  end

  def _evaluate_assigns_and_ivars() end

  def test_insert_html_with_string
    assert_equal 'Element.insert("element", { top: "\\u003Cp\\u003EThis is a test\\u003C/p\\u003E" });',
      @generator.insert_html(:top, 'element', '<p>This is a test</p>')
    assert_equal 'Element.insert("element", { bottom: "\\u003Cp\u003EThis is a test\\u003C/p\u003E" });',
      @generator.insert_html(:bottom, 'element', '<p>This is a test</p>')
    assert_equal 'Element.insert("element", { before: "\\u003Cp\u003EThis is a test\\u003C/p\u003E" });',
      @generator.insert_html(:before, 'element', '<p>This is a test</p>')
    assert_equal 'Element.insert("element", { after: "\\u003Cp\u003EThis is a test\\u003C/p\u003E" });',
      @generator.insert_html(:after, 'element', '<p>This is a test</p>')
  end

  def test_replace_html_with_string
    assert_equal 'Element.update("element", "\\u003Cp\\u003EThis is a test\\u003C/p\\u003E");',
      @generator.replace_html('element', '<p>This is a test</p>')
  end

  def test_replace_element_with_string
    assert_equal 'Element.replace("element", "\\u003Cdiv id=\"element\"\\u003E\\u003Cp\\u003EThis is a test\\u003C/p\\u003E\\u003C/div\\u003E");',
      @generator.replace('element', '<div id="element"><p>This is a test</p></div>')
  end

  def test_remove
    assert_equal 'Element.remove("foo");',
      @generator.remove('foo')
    assert_equal '["foo","bar","baz"].each(Element.remove);',
      @generator.remove('foo', 'bar', 'baz')
  end

  def test_show
    assert_equal 'Element.show("foo");',
      @generator.show('foo')
    assert_equal '["foo","bar","baz"].each(Element.show);',
      @generator.show('foo', 'bar', 'baz')
  end

  def test_hide
    assert_equal 'Element.hide("foo");',
      @generator.hide('foo')
    assert_equal '["foo","bar","baz"].each(Element.hide);',
      @generator.hide('foo', 'bar', 'baz')
  end

  def test_toggle
    assert_equal 'Element.toggle("foo");',
      @generator.toggle('foo')
    assert_equal '["foo","bar","baz"].each(Element.toggle);',
      @generator.toggle('foo', 'bar', 'baz')
  end

  def test_alert
    assert_equal 'alert("hello");', @generator.alert('hello')
  end

  def test_redirect_to
    assert_equal 'window.location.href = "http://www.example.com/welcome";',
      @generator.redirect_to(:action => 'welcome')
    assert_equal 'window.location.href = "http://www.example.com/welcome?a=b&c=d";',
      @generator.redirect_to("http://www.example.com/welcome?a=b&c=d")
  end

  def test_reload
    assert_equal 'window.location.reload();',
      @generator.reload
  end

  def test_delay
    @generator.delay(20) do
      @generator.hide('foo')
    end

    assert_equal "setTimeout(function() {\n;\nElement.hide(\"foo\");\n}, 20000);", @generator.to_s
  end

  def test_to_s
    @generator.insert_html(:top, 'element', '<p>This is a test</p>')
    @generator.insert_html(:bottom, 'element', '<p>This is a test</p>')
    @generator.remove('foo', 'bar')
    @generator.replace_html('baz', '<p>This is a test</p>')

    assert_equal <<-EOS.chomp, @generator.to_s
Element.insert("element", { top: "\\u003Cp\\u003EThis is a test\\u003C/p\\u003E" });
Element.insert("element", { bottom: "\\u003Cp\\u003EThis is a test\\u003C/p\\u003E" });
["foo","bar"].each(Element.remove);
Element.update("baz", "\\u003Cp\\u003EThis is a test\\u003C/p\\u003E");
    EOS
  end

  def test_element_access
    assert_equal %($("hello");), @generator['hello']
  end

  def test_element_access_on_records
    assert_equal %($("bunny_5");),   @generator[Bunny.new(:id => 5)]
    assert_equal %($("new_bunny");), @generator[Bunny.new]
  end

  def test_element_proxy_one_deep
    @generator['hello'].hide
    assert_equal %($("hello").hide();), @generator.to_s
  end

  def test_element_proxy_variable_access
    @generator['hello']['style']
    assert_equal %($("hello").style;), @generator.to_s
  end

  def test_element_proxy_variable_access_with_assignment
    @generator['hello']['style']['color'] = 'red'
    assert_equal %($("hello").style.color = "red";), @generator.to_s
  end

  def test_element_proxy_assignment
    @generator['hello'].width = 400
    assert_equal %($("hello").width = 400;), @generator.to_s
  end

  def test_element_proxy_two_deep
    @generator['hello'].hide("first").clean_whitespace
    assert_equal %($("hello").hide("first").cleanWhitespace();), @generator.to_s
  end

  def test_select_access
    assert_equal %($$("div.hello");), @generator.select('div.hello')
  end

  def test_select_proxy_one_deep
    @generator.select('p.welcome b').first.hide
    assert_equal %($$("p.welcome b").first().hide();), @generator.to_s
  end

  def test_visual_effect
    assert_equal %(new Effect.Puff("blah",{});),
      @generator.visual_effect(:puff,'blah')
  end

  def test_visual_effect_toggle
    assert_equal %(Effect.toggle("blah",'appear',{});),
      @generator.visual_effect(:toggle_appear,'blah')
  end

  def test_sortable
    assert_equal %(Sortable.create("blah", {onUpdate:function(){new Ajax.Request('http://www.example.com/order', {asynchronous:true, evalScripts:true, parameters:Sortable.serialize("blah")})}});),
      @generator.sortable('blah', :url => { :action => "order" })
    assert_equal %(Sortable.create("blah", {onUpdate:function(){new Ajax.Request('http://www.example.com/order', {asynchronous:false, evalScripts:true, parameters:Sortable.serialize("blah")})}});),
      @generator.sortable('blah', :url => { :action => "order" }, :type => :synchronous)
  end

  def test_draggable
    assert_equal %(new Draggable("blah", {});),
      @generator.draggable('blah')
  end

  def test_drop_receiving
    assert_equal %(Droppables.add("blah", {onDrop:function(element){new Ajax.Request('http://www.example.com/order', {asynchronous:true, evalScripts:true, parameters:'id=' + encodeURIComponent(element.id)})}});),
      @generator.drop_receiving('blah', :url => { :action => "order" })
    assert_equal %(Droppables.add("blah", {onDrop:function(element){new Ajax.Request('http://www.example.com/order', {asynchronous:false, evalScripts:true, parameters:'id=' + encodeURIComponent(element.id)})}});),
      @generator.drop_receiving('blah', :url => { :action => "order" }, :type => :synchronous)
  end

  def test_collection_first_and_last
    @generator.select('p.welcome b').first.hide()
    @generator.select('p.welcome b').last.show()
    assert_equal <<-EOS.strip, @generator.to_s
$$("p.welcome b").first().hide();
$$("p.welcome b").last().show();
      EOS
  end

  def test_collection_proxy_with_each
    @generator.select('p.welcome b').each do |value|
      value.remove_class_name 'selected'
    end
    @generator.select('p.welcome b').each do |value, index|
      @generator.visual_effect :highlight, value
    end
    assert_equal <<-EOS.strip, @generator.to_s
$$("p.welcome b").each(function(value, index) {
value.removeClassName("selected");
});
$$("p.welcome b").each(function(value, index) {
new Effect.Highlight(value,{});
});
      EOS
  end

  def test_collection_proxy_on_collect
    @generator.select('p').collect('a') { |para| para.show }
    @generator.select('p').collect { |para| para.hide }
    assert_equal <<-EOS.strip, @generator.to_s
var a = $$("p").collect(function(value, index) {
return value.show();
});
$$("p").collect(function(value, index) {
return value.hide();
});
    EOS
    @generator = create_generator
  end

  def test_collection_proxy_with_grep
    @generator.select('p').grep 'a', /^a/ do |value|
      @generator << '(value.className == "welcome")'
    end
    @generator.select('p').grep 'b', /b$/ do |value, index|
      @generator.call 'alert', value
      @generator << '(value.className == "welcome")'
    end

    assert_equal <<-EOS.strip, @generator.to_s
var a = $$("p").grep(/^a/, function(value, index) {
return (value.className == "welcome");
});
var b = $$("p").grep(/b$/, function(value, index) {
alert(value);
return (value.className == "welcome");
});
    EOS
  end

  def test_collection_proxy_with_inject
    @generator.select('p').inject 'a', [] do |memo, value|
      @generator << '(value.className == "welcome")'
    end
    @generator.select('p').inject 'b', nil do |memo, value, index|
      @generator.call 'alert', memo
      @generator << '(value.className == "welcome")'
    end

    assert_equal <<-EOS.strip, @generator.to_s
var a = $$("p").inject([], function(memo, value, index) {
return (value.className == "welcome");
});
var b = $$("p").inject(null, function(memo, value, index) {
alert(memo);
return (value.className == "welcome");
});
    EOS
  end

  def test_collection_proxy_with_pluck
    @generator.select('p').pluck('a', 'className')
    assert_equal %(var a = $$("p").pluck("className");), @generator.to_s
  end

  def test_collection_proxy_with_zip
    ActionView::Helpers::JavaScriptCollectionProxy.new(@generator, '[1, 2, 3]').zip('a', [4, 5, 6], [7, 8, 9])
    ActionView::Helpers::JavaScriptCollectionProxy.new(@generator, '[1, 2, 3]').zip('b', [4, 5, 6], [7, 8, 9]) do |array|
      @generator.call 'array.reverse'
    end

    assert_equal <<-EOS.strip, @generator.to_s
var a = [1, 2, 3].zip([4,5,6], [7,8,9]);
var b = [1, 2, 3].zip([4,5,6], [7,8,9], function(array) {
return array.reverse();
});
    EOS
  end

  def test_collection_proxy_with_find_all
    @generator.select('p').find_all 'a' do |value, index|
      @generator << '(value.className == "welcome")'
    end

    assert_equal <<-EOS.strip, @generator.to_s
var a = $$("p").findAll(function(value, index) {
return (value.className == "welcome");
});
    EOS
  end

  def test_collection_proxy_with_in_groups_of
    @generator.select('p').in_groups_of('a', 3)
    @generator.select('p').in_groups_of('a', 3, 'x')
    assert_equal <<-EOS.strip, @generator.to_s
var a = $$("p").inGroupsOf(3);
var a = $$("p").inGroupsOf(3, "x");
    EOS
  end

  def test_collection_proxy_with_each_slice
    @generator.select('p').each_slice('a', 3)
    @generator.select('p').each_slice('a', 3) do |group, index|
      group.reverse
    end

    assert_equal <<-EOS.strip, @generator.to_s
var a = $$("p").eachSlice(3);
var a = $$("p").eachSlice(3, function(value, index) {
return value.reverse();
});
    EOS
  end

  def test_debug_rjs
    ActionView::Base.debug_rjs = true
    @generator['welcome'].replace_html 'Welcome'
    assert_equal "try {\n$(\"welcome\").update(\"Welcome\");\n} catch (e) { alert('RJS error:\\n\\n' + e.toString()); alert('$(\\\"welcome\\\").update(\\\"Welcome\\\");'); throw e }", @generator.to_s
  ensure
    ActionView::Base.debug_rjs = false
  end

  def test_literal
    literal = @generator.literal("function() {}")
    assert_equal "function() {}", ActiveSupport::JSON.encode(literal)
    assert_equal "", @generator.to_s
  end

  def test_class_proxy
    @generator.form.focus('my_field')
    assert_equal "Form.focus(\"my_field\");", @generator.to_s
  end

  def test_call_with_block
    @generator.call(:before)
    @generator.call(:my_method) do |p|
      p[:one].show
      p[:two].hide
    end
    @generator.call(:in_between)
    @generator.call(:my_method_with_arguments, true, "hello") do |p|
      p[:three].visual_effect(:highlight)
    end
    assert_equal "before();\nmy_method(function() { $(\"one\").show();\n$(\"two\").hide(); });\nin_between();\nmy_method_with_arguments(true, \"hello\", function() { $(\"three\").visualEffect(\"highlight\"); });", @generator.to_s
  end

  def test_class_proxy_call_with_block
    @generator.my_object.my_method do |p|
      p[:one].show
      p[:two].hide
    end
    assert_equal "MyObject.myMethod(function() { $(\"one\").show();\n$(\"two\").hide(); });", @generator.to_s
  end
end
