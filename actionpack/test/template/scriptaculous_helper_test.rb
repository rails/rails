require "#{File.dirname(__FILE__)}/../abstract_unit"

class ScriptaculousHelperTest < Test::Unit::TestCase
  include ActionView::Helpers::JavaScriptHelper
  include ActionView::Helpers::PrototypeHelper
  include ActionView::Helpers::ScriptaculousHelper
  
  include ActionView::Helpers::UrlHelper
  include ActionView::Helpers::TagHelper
  include ActionView::Helpers::TextHelper
  include ActionView::Helpers::FormHelper
  include ActionView::Helpers::CaptureHelper
  
  def setup
    @controller = Class.new do
      def url_for(options)
        url =  "http://www.example.com/"
        url << options[:action].to_s if options and options[:action]
        url
      end
    end.new
  end
  
  def test_effect
    assert_equal "new Effect.Highlight(\"posts\",{});", visual_effect(:highlight, "posts")
    assert_equal "new Effect.Highlight(\"posts\",{});", visual_effect("highlight", :posts)
    assert_equal "new Effect.Highlight(\"posts\",{});", visual_effect(:highlight, :posts)    
    assert_equal "new Effect.Fade(\"fademe\",{duration:4.0});", visual_effect(:fade, "fademe", :duration => 4.0)
    assert_equal "new Effect.Shake(element,{});", visual_effect(:shake)
    assert_equal "new Effect.DropOut(\"dropme\",{queue:'end'});", visual_effect(:drop_out, 'dropme', :queue => :end)
    assert_equal "new Effect.Highlight(\"status\",{endcolor:'#EEEEEE'});", visual_effect(:highlight, 'status', :endcolor => '#EEEEEE')
    assert_equal "new Effect.Highlight(\"status\",{restorecolor:'#500000', startcolor:'#FEFEFE'});", visual_effect(:highlight, 'status', :restorecolor => '#500000', :startcolor => '#FEFEFE')

    # chop the queue params into a comma separated list
    beginning, ending = 'new Effect.DropOut("dropme",{queue:{', '}});'
    ve = [
      visual_effect(:drop_out, 'dropme', :queue => {:position => "end", :scope => "test", :limit => 2}),
      visual_effect(:drop_out, 'dropme', :queue => {:scope => :list, :limit => 2}),
      visual_effect(:drop_out, 'dropme', :queue => {:position => :end, :scope => :test, :limit => 2})
    ].collect { |v| v[beginning.length..-ending.length-1].split(',') }

    assert ve[0].include?("limit:2")
    assert ve[0].include?("scope:'test'")
    assert ve[0].include?("position:'end'")

    assert ve[1].include?("limit:2")
    assert ve[1].include?("scope:'list'")

    assert ve[2].include?("limit:2")
    assert ve[2].include?("scope:'test'")
    assert ve[2].include?("position:'end'")
  end
  
  def test_toggle_effects
    assert_equal "Effect.toggle(\"posts\",'appear',{});", visual_effect(:toggle_appear,  "posts")
    assert_equal "Effect.toggle(\"posts\",'slide',{});",  visual_effect(:toggle_slide,   "posts")
    assert_equal "Effect.toggle(\"posts\",'blind',{});",  visual_effect(:toggle_blind,   "posts")
    assert_equal "Effect.toggle(\"posts\",'appear',{});", visual_effect("toggle_appear", "posts")
    assert_equal "Effect.toggle(\"posts\",'slide',{});",  visual_effect("toggle_slide",  "posts")
    assert_equal "Effect.toggle(\"posts\",'blind',{});",  visual_effect("toggle_blind",  "posts")
  end
  

  def test_sortable_element
    assert_dom_equal %(<script type=\"text/javascript\">\n//<![CDATA[\nSortable.create(\"mylist\", {onUpdate:function(){new Ajax.Request('http://www.example.com/order', {asynchronous:true, evalScripts:true, parameters:Sortable.serialize(\"mylist\")})}})\n//]]>\n</script>), 
      sortable_element("mylist", :url => { :action => "order" })
    assert_equal %(<script type=\"text/javascript\">\n//<![CDATA[\nSortable.create(\"mylist\", {constraint:'horizontal', onUpdate:function(){new Ajax.Request('http://www.example.com/order', {asynchronous:true, evalScripts:true, parameters:Sortable.serialize(\"mylist\")})}, tag:'div'})\n//]]>\n</script>), 
      sortable_element("mylist", :tag => "div", :constraint => "horizontal", :url => { :action => "order" })
    assert_dom_equal %|<script type=\"text/javascript\">\n//<![CDATA[\nSortable.create(\"mylist\", {constraint:'horizontal', containment:['list1','list2'], onUpdate:function(){new Ajax.Request('http://www.example.com/order', {asynchronous:true, evalScripts:true, parameters:Sortable.serialize(\"mylist\")})}})\n//]]>\n</script>|, 
      sortable_element("mylist", :containment => ['list1','list2'], :constraint => "horizontal", :url => { :action => "order" })
    assert_dom_equal %(<script type=\"text/javascript\">\n//<![CDATA[\nSortable.create(\"mylist\", {constraint:'horizontal', containment:'list1', onUpdate:function(){new Ajax.Request('http://www.example.com/order', {asynchronous:true, evalScripts:true, parameters:Sortable.serialize(\"mylist\")})}})\n//]]>\n</script>), 
      sortable_element("mylist", :containment => 'list1', :constraint => "horizontal", :url => { :action => "order" })
  end
  
  def test_draggable_element
    assert_dom_equal %(<script type=\"text/javascript\">\n//<![CDATA[\nnew Draggable(\"product_13\", {})\n//]]>\n</script>),
      draggable_element("product_13")
    assert_equal %(<script type=\"text/javascript\">\n//<![CDATA[\nnew Draggable(\"product_13\", {revert:true})\n//]]>\n</script>),
      draggable_element("product_13", :revert => true)
  end
  
  def test_drop_receiving_element
    assert_dom_equal %(<script type=\"text/javascript\">\n//<![CDATA[\nDroppables.add(\"droptarget1\", {onDrop:function(element){new Ajax.Request('http://www.example.com/', {asynchronous:true, evalScripts:true, parameters:'id=' + encodeURIComponent(element.id)})}})\n//]]>\n</script>),
      drop_receiving_element("droptarget1")
    assert_dom_equal %(<script type=\"text/javascript\">\n//<![CDATA[\nDroppables.add(\"droptarget1\", {accept:'products', onDrop:function(element){new Ajax.Request('http://www.example.com/', {asynchronous:true, evalScripts:true, parameters:'id=' + encodeURIComponent(element.id)})}})\n//]]>\n</script>),
      drop_receiving_element("droptarget1", :accept => 'products')
    assert_dom_equal %(<script type=\"text/javascript\">\n//<![CDATA[\nDroppables.add(\"droptarget1\", {accept:'products', onDrop:function(element){new Ajax.Updater('infobox', 'http://www.example.com/', {asynchronous:true, evalScripts:true, parameters:'id=' + encodeURIComponent(element.id)})}})\n//]]>\n</script>),
      drop_receiving_element("droptarget1", :accept => 'products', :update => 'infobox')
    assert_dom_equal %(<script type=\"text/javascript\">\n//<![CDATA[\nDroppables.add(\"droptarget1\", {accept:['tshirts','mugs'], onDrop:function(element){new Ajax.Updater('infobox', 'http://www.example.com/', {asynchronous:true, evalScripts:true, parameters:'id=' + encodeURIComponent(element.id)})}})\n//]]>\n</script>),
      drop_receiving_element("droptarget1", :accept => ['tshirts','mugs'], :update => 'infobox')
  end

  def protect_against_forgery?
    false
  end
end
