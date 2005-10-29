require File.dirname(__FILE__) + '/../abstract_unit'

class JavaScriptHelperTest < Test::Unit::TestCase
  include ActionView::Helpers::JavaScriptHelper
  
  include ActionView::Helpers::UrlHelper
  include ActionView::Helpers::TagHelper
  include ActionView::Helpers::TextHelper
  include ActionView::Helpers::FormHelper
  include ActionView::Helpers::CaptureHelper
  
  def setup
    @controller = Class.new do
      def url_for(options, *parameters_for_method_reference)
        url =  "http://www.example.com/"
        url << options[:action].to_s if options and options[:action]
        url
      end
    end
    @controller = @controller.new
  end
  
  def test_define_javascript_functions
    # check if prototype.js is included first
    assert_not_nil define_javascript_functions.split("\n")[1].match(/Prototype JavaScript framework/)
    
    # check that scriptaculous.js is not in here, only needed if loaded remotely
    assert_nil define_javascript_functions.split("\n")[1].match(/var Scriptaculous = \{/)
  end

  def test_escape_javascript
    assert_equal %(This \\"thing\\" is really\\n netos\\'), escape_javascript(%(This "thing" is really\n netos'))
  end
                                      
  def test_link_to_function
    assert_dom_equal %(<a href="#" onclick="alert('Hello world!'); return false;">Greeting</a>), 
      link_to_function("Greeting", "alert('Hello world!')")
  end
  
  def test_link_to_remote
    assert_dom_equal %(<a class=\"fine\" href=\"#\" onclick=\"new Ajax.Request('http://www.example.com/whatnot', {asynchronous:true, evalScripts:true}); return false;\">Remote outpost</a>),
      link_to_remote("Remote outpost", { :url => { :action => "whatnot"  }}, { :class => "fine"  })
    assert_dom_equal %(<a href=\"#\" onclick=\"new Ajax.Request('http://www.example.com/whatnot', {asynchronous:true, evalScripts:true, onComplete:function(request){alert(request.reponseText)}}); return false;\">Remote outpost</a>),
      link_to_remote("Remote outpost", :complete => "alert(request.reponseText)", :url => { :action => "whatnot"  })      
    assert_dom_equal %(<a href=\"#\" onclick=\"new Ajax.Request('http://www.example.com/whatnot', {asynchronous:true, evalScripts:true, onSuccess:function(request){alert(request.reponseText)}}); return false;\">Remote outpost</a>),
      link_to_remote("Remote outpost", :success => "alert(request.reponseText)", :url => { :action => "whatnot"  })
    assert_dom_equal %(<a href=\"#\" onclick=\"new Ajax.Request('http://www.example.com/whatnot', {asynchronous:true, evalScripts:true, onFailure:function(request){alert(request.reponseText)}}); return false;\">Remote outpost</a>),
      link_to_remote("Remote outpost", :failure => "alert(request.reponseText)", :url => { :action => "whatnot"  })
  end
  
  def test_periodically_call_remote
    assert_dom_equal %(<script type="text/javascript">\n//<![CDATA[\nnew PeriodicalExecuter(function() {new Ajax.Updater('schremser_bier', 'http://www.example.com/mehr_bier', {asynchronous:true, evalScripts:true})}, 10)\n//]]>\n</script>),
      periodically_call_remote(:update => "schremser_bier", :url => { :action => "mehr_bier" })
  end
  
  def test_form_remote_tag
    assert_dom_equal %(<form action=\"http://www.example.com/fast\" method=\"post\" onsubmit=\"new Ajax.Updater('glass_of_beer', 'http://www.example.com/fast', {asynchronous:true, evalScripts:true, parameters:Form.serialize(this)}); return false;\">),
      form_remote_tag(:update => "glass_of_beer", :url => { :action => :fast  })
    assert_dom_equal %(<form action=\"http://www.example.com/fast\" method=\"post\" onsubmit=\"new Ajax.Updater({success:'glass_of_beer'}, 'http://www.example.com/fast', {asynchronous:true, evalScripts:true, parameters:Form.serialize(this)}); return false;\">),
      form_remote_tag(:update => { :success => "glass_of_beer" }, :url => { :action => :fast  })
    assert_dom_equal %(<form action=\"http://www.example.com/fast\" method=\"post\" onsubmit=\"new Ajax.Updater({failure:'glass_of_water'}, 'http://www.example.com/fast', {asynchronous:true, evalScripts:true, parameters:Form.serialize(this)}); return false;\">),
      form_remote_tag(:update => { :failure => "glass_of_water" }, :url => { :action => :fast  })
    assert_dom_equal %(<form action=\"http://www.example.com/fast\" method=\"post\" onsubmit=\"new Ajax.Updater({success:'glass_of_beer',failure:'glass_of_water'}, 'http://www.example.com/fast', {asynchronous:true, evalScripts:true, parameters:Form.serialize(this)}); return false;\">),
      form_remote_tag(:update => { :success => 'glass_of_beer', :failure => "glass_of_water" }, :url => { :action => :fast  })
  end
  
  def test_on_callbacks
    callbacks = [:uninitialized, :loading, :loaded, :interactive, :complete, :success, :failure]
    callbacks.each do |callback|
      assert_dom_equal %(<form action=\"http://www.example.com/fast\" method=\"post\" onsubmit=\"new Ajax.Updater('glass_of_beer', 'http://www.example.com/fast', {asynchronous:true, evalScripts:true, on#{callback.to_s.capitalize}:function(request){monkeys();}, parameters:Form.serialize(this)}); return false;">),
        form_remote_tag(:update => "glass_of_beer", :url => { :action => :fast  }, callback=>"monkeys();")
      assert_dom_equal %(<form action=\"http://www.example.com/fast\" method=\"post\" onsubmit=\"new Ajax.Updater({success:'glass_of_beer'}, 'http://www.example.com/fast', {asynchronous:true, evalScripts:true, on#{callback.to_s.capitalize}:function(request){monkeys();}, parameters:Form.serialize(this)}); return false;">),
        form_remote_tag(:update => { :success => "glass_of_beer" }, :url => { :action => :fast  }, callback=>"monkeys();")
      assert_dom_equal %(<form action=\"http://www.example.com/fast\" method=\"post\" onsubmit=\"new Ajax.Updater({failure:'glass_of_beer'}, 'http://www.example.com/fast', {asynchronous:true, evalScripts:true, on#{callback.to_s.capitalize}:function(request){monkeys();}, parameters:Form.serialize(this)}); return false;">),
        form_remote_tag(:update => { :failure => "glass_of_beer" }, :url => { :action => :fast  }, callback=>"monkeys();")
      assert_dom_equal %(<form action=\"http://www.example.com/fast\" method=\"post\" onsubmit=\"new Ajax.Updater({success:'glass_of_beer',failure:'glass_of_water'}, 'http://www.example.com/fast', {asynchronous:true, evalScripts:true, on#{callback.to_s.capitalize}:function(request){monkeys();}, parameters:Form.serialize(this)}); return false;">),
        form_remote_tag(:update => { :success => "glass_of_beer", :failure => "glass_of_water" }, :url => { :action => :fast  }, callback=>"monkeys();")
    end
    
    #HTTP status codes 200 up to 599 have callbacks
    #these should work
    100.upto(599) do |callback|
      assert_dom_equal %(<form action=\"http://www.example.com/fast\" method=\"post\" onsubmit=\"new Ajax.Updater('glass_of_beer', 'http://www.example.com/fast', {asynchronous:true, evalScripts:true, on#{callback.to_s.capitalize}:function(request){monkeys();}, parameters:Form.serialize(this)}); return false;">),
        form_remote_tag(:update => "glass_of_beer", :url => { :action => :fast  }, callback=>"monkeys();")
    end
    
    #test 200 and 404
    assert_dom_equal %(<form action=\"http://www.example.com/fast\" method=\"post\" onsubmit=\"new Ajax.Updater('glass_of_beer', 'http://www.example.com/fast', {asynchronous:true, evalScripts:true, on200:function(request){monkeys();}, on404:function(request){bananas();}, parameters:Form.serialize(this)}); return false;">),
      form_remote_tag(:update => "glass_of_beer", :url => { :action => :fast  }, 200=>"monkeys();", 404=>"bananas();")
    
    #these shouldn't
    1.upto(99) do |callback|
      assert_dom_equal %(<form action=\"http://www.example.com/fast\" method=\"post\" onsubmit=\"new Ajax.Updater('glass_of_beer', 'http://www.example.com/fast', {asynchronous:true, evalScripts:true, parameters:Form.serialize(this)}); return false;">),
        form_remote_tag(:update => "glass_of_beer", :url => { :action => :fast  }, callback=>"monkeys();")
    end
    600.upto(999) do |callback|
      assert_dom_equal %(<form action=\"http://www.example.com/fast\" method=\"post\" onsubmit=\"new Ajax.Updater('glass_of_beer', 'http://www.example.com/fast', {asynchronous:true, evalScripts:true, parameters:Form.serialize(this)}); return false;">),
        form_remote_tag(:update => "glass_of_beer", :url => { :action => :fast  }, callback=>"monkeys();")
    end
    
    #test ultimate combo
    assert_dom_equal %(<form action=\"http://www.example.com/fast\" method=\"post\" onsubmit=\"new Ajax.Updater('glass_of_beer', 'http://www.example.com/fast', {asynchronous:true, evalScripts:true, on200:function(request){monkeys();}, on404:function(request){bananas();}, onComplete:function(request){c();}, onFailure:function(request){f();}, onLoading:function(request){c1()}, onSuccess:function(request){s()}, parameters:Form.serialize(this)}); return false;\">),
      form_remote_tag(:update => "glass_of_beer", :url => { :action => :fast  }, :loading => "c1()", :success => "s()", :failure => "f();", :complete => "c();", 200=>"monkeys();", 404=>"bananas();")
    
  end
  
  def test_submit_to_remote
    assert_dom_equal %(<input name=\"More beer!\" onclick=\"new Ajax.Updater('empty_bottle', 'http://www.example.com/', {asynchronous:true, evalScripts:true, parameters:Form.serialize(this.form)}); return false;\" type=\"button\" value=\"1000000\" />),
      submit_to_remote("More beer!", 1_000_000, :update => "empty_bottle")
  end
  
  def test_observe_field
    assert_dom_equal %(<script type=\"text/javascript\">\n//<![CDATA[\nnew Form.Element.Observer('glass', 300, function(element, value) {new Ajax.Request('http://www.example.com/reorder_if_empty', {asynchronous:true, evalScripts:true})})\n//]]>\n</script>),
      observe_field("glass", :frequency => 5.minutes, :url => { :action => "reorder_if_empty" })
  end
  
  def test_observe_form
    assert_dom_equal %(<script type=\"text/javascript\">\n//<![CDATA[\nnew Form.Observer('cart', 2, function(element, value) {new Ajax.Request('http://www.example.com/cart_changed', {asynchronous:true, evalScripts:true})})\n//]]>\n</script>),
      observe_form("cart", :frequency => 2, :url => { :action => "cart_changed" })
  end
  
  def test_effect
    assert_equal "new Effect.Highlight('posts',{});", visual_effect(:highlight, "posts")
    assert_equal "new Effect.Highlight('posts',{});", visual_effect("highlight", :posts)
    assert_equal "new Effect.Highlight('posts',{});", visual_effect(:highlight, :posts)    
    assert_equal "new Effect.Fade('fademe',{duration:4.0});", visual_effect(:fade, "fademe", :duration => 4.0)
    assert_equal "new Effect.Shake(element,{});", visual_effect(:shake)
    assert_equal "new Effect.DropOut('dropme',{queue:'end'});", visual_effect(:drop_out, 'dropme', :queue => :end)
  end
  
  def test_sortable_element
    assert_dom_equal %(<script type=\"text/javascript\">\n//<![CDATA[\nSortable.create('mylist', {onUpdate:function(){new Ajax.Request('http://www.example.com/order', {asynchronous:true, evalScripts:true, parameters:Sortable.serialize('mylist')})}})\n//]]>\n</script>), 
      sortable_element("mylist", :url => { :action => "order" })
    assert_equal %(<script type=\"text/javascript\">\n//<![CDATA[\nSortable.create('mylist', {constraint:'horizontal', onUpdate:function(){new Ajax.Request('http://www.example.com/order', {asynchronous:true, evalScripts:true, parameters:Sortable.serialize('mylist')})}, tag:'div'})\n//]]>\n</script>), 
      sortable_element("mylist", :tag => "div", :constraint => "horizontal", :url => { :action => "order" })
    assert_dom_equal %|<script type=\"text/javascript\">\n//<![CDATA[\nSortable.create('mylist', {constraint:'horizontal', containment:['list1','list2'], onUpdate:function(){new Ajax.Request('http://www.example.com/order', {asynchronous:true, evalScripts:true, parameters:Sortable.serialize('mylist')})}})\n//]]>\n</script>|, 
      sortable_element("mylist", :containment => ['list1','list2'], :constraint => "horizontal", :url => { :action => "order" })
    assert_dom_equal %(<script type=\"text/javascript\">\n//<![CDATA[\nSortable.create('mylist', {constraint:'horizontal', containment:'list1', onUpdate:function(){new Ajax.Request('http://www.example.com/order', {asynchronous:true, evalScripts:true, parameters:Sortable.serialize('mylist')})}})\n//]]>\n</script>), 
      sortable_element("mylist", :containment => 'list1', :constraint => "horizontal", :url => { :action => "order" })
  end
  
  def test_draggable_element
    assert_dom_equal %(<script type=\"text/javascript\">\n//<![CDATA[\nnew Draggable('product_13', {})\n//]]>\n</script>),
      draggable_element('product_13')
    assert_equal %(<script type=\"text/javascript\">\n//<![CDATA[\nnew Draggable('product_13', {revert:true})\n//]]>\n</script>),
      draggable_element('product_13', :revert => true)
  end
  
  def test_drop_receiving_element
    assert_dom_equal %(<script type=\"text/javascript\">\n//<![CDATA[\nDroppables.add('droptarget1', {onDrop:function(element){new Ajax.Request('http://www.example.com/', {asynchronous:true, evalScripts:true, parameters:'id=' + encodeURIComponent(element.id)})}})\n//]]>\n</script>),
      drop_receiving_element('droptarget1')
    assert_dom_equal %(<script type=\"text/javascript\">\n//<![CDATA[\nDroppables.add('droptarget1', {accept:'products', onDrop:function(element){new Ajax.Request('http://www.example.com/', {asynchronous:true, evalScripts:true, parameters:'id=' + encodeURIComponent(element.id)})}})\n//]]>\n</script>),
      drop_receiving_element('droptarget1', :accept => 'products')
    assert_dom_equal %(<script type=\"text/javascript\">\n//<![CDATA[\nDroppables.add('droptarget1', {accept:'products', onDrop:function(element){new Ajax.Updater('infobox', 'http://www.example.com/', {asynchronous:true, evalScripts:true, parameters:'id=' + encodeURIComponent(element.id)})}})\n//]]>\n</script>),
      drop_receiving_element('droptarget1', :accept => 'products', :update => 'infobox')
    assert_dom_equal %(<script type=\"text/javascript\">\n//<![CDATA[\nDroppables.add('droptarget1', {accept:['tshirts','mugs'], onDrop:function(element){new Ajax.Updater('infobox', 'http://www.example.com/', {asynchronous:true, evalScripts:true, parameters:'id=' + encodeURIComponent(element.id)})}})\n//]]>\n</script>),
      drop_receiving_element('droptarget1', :accept => ['tshirts','mugs'], :update => 'infobox')
  end
  
  def test_update_element_function
    assert_equal %($('myelement').innerHTML = 'blub';\n),
      update_element_function('myelement', :content => 'blub')
    assert_equal %($('myelement').innerHTML = 'blub';\n),
      update_element_function('myelement', :action => :update, :content => 'blub')
    assert_equal %($('myelement').innerHTML = '';\n),
      update_element_function('myelement', :action => :empty)
    assert_equal %(Element.remove('myelement');\n),
      update_element_function('myelement', :action => :remove)
      
    assert_equal %(new Insertion.Bottom('myelement','blub');\n),
      update_element_function('myelement', :position => 'bottom', :content => 'blub')
    assert_equal %(new Insertion.Bottom('myelement','blub');\n),
      update_element_function('myelement', :action => :update, :position => :bottom, :content => 'blub')
      
    _erbout = ""
    assert_equal %($('myelement').innerHTML = 'test';\n),
      update_element_function('myelement') { _erbout << "test" }
      
    _erbout = ""
    assert_equal %($('myelement').innerHTML = 'blockstuff';\n),
      update_element_function('myelement', :content => 'paramstuff') { _erbout << "blockstuff" }
  end
  
end
