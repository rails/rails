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
  end

  def test_escape_javascript
    assert_equal %(This \\"thing\\" is really\\n netos\\'), escape_javascript(%(This "thing" is really\n netos'))
  end
  
  def test_link_to_function
    assert_equal %(<a href="#" onclick="alert('Hello world!'); return false;">Greeting</a>), 
      link_to_function("Greeting", "alert('Hello world!')")
  end
  
  def test_link_to_remote
    assert_equal %(<a class=\"fine\" href=\"#\" onclick=\"new Ajax.Request('http://www.example.com/whatnot', {asynchronous:true, evalScripts:true}); return false;\">Remote outpost</a>),
      link_to_remote("Remote outpost", { :url => { :action => "whatnot"  }}, { :class => "fine"  })
    assert_equal %(<a href=\"#\" onclick=\"new Ajax.Request('http://www.example.com/whatnot', {asynchronous:true, evalScripts:true, onComplete:function(request){alert(request.reponseText)}}); return false;\">Remote outpost</a>),
      link_to_remote("Remote outpost", :complete => "alert(request.reponseText)", :url => { :action => "whatnot"  })
  end
  
  def test_periodically_call_remote
    assert_equal %(<script>new PeriodicalExecuter(function() {new Ajax.Updater('schremser_bier', 'http://www.example.com/mehr_bier', {asynchronous:true, evalScripts:true})}, 10)</script>),
      periodically_call_remote(:update => "schremser_bier", :url => { :action => "mehr_bier" })
  end
  
  def test_form_remote_tag
    assert_equal %(<form action=\"http://www.example.com/fast\" method=\"post\" onsubmit=\"new Ajax.Updater('glass_of_beer', 'http://www.example.com/fast', {asynchronous:true, evalScripts:true, parameters:Form.serialize(this)}); return false;\">),
      form_remote_tag(:update => "glass_of_beer", :url => { :action => :fast  })
    assert_equal %(<form action=\"http://www.example.com/fast\" method=\"post\" onsubmit=\"new Ajax.Updater({success:'glass_of_beer'}, 'http://www.example.com/fast', {asynchronous:true, evalScripts:true, parameters:Form.serialize(this)}); return false;\">),
      form_remote_tag(:update => { :success => "glass_of_beer" }, :url => { :action => :fast  })
    assert_equal %(<form action=\"http://www.example.com/fast\" method=\"post\" onsubmit=\"new Ajax.Updater({failure:'glass_of_water'}, 'http://www.example.com/fast', {asynchronous:true, evalScripts:true, parameters:Form.serialize(this)}); return false;\">),
      form_remote_tag(:update => { :failure => "glass_of_water" }, :url => { :action => :fast  })
    assert_equal %(<form action=\"http://www.example.com/fast\" method=\"post\" onsubmit=\"new Ajax.Updater({success:'glass_of_beer',failure:'glass_of_water'}, 'http://www.example.com/fast', {asynchronous:true, evalScripts:true, parameters:Form.serialize(this)}); return false;\">),
      form_remote_tag(:update => { :success => 'glass_of_beer', :failure => "glass_of_water" }, :url => { :action => :fast  })
  end
  
  def test_submit_to_remote
    assert_equal %(<input name=\"More beer!\" onclick=\"new Ajax.Updater('empty_bottle', 'http://www.example.com/', {asynchronous:true, evalScripts:true, parameters:Form.serialize(this.form)}); return false;\" type=\"button\" value=\"1000000\" />),
      submit_to_remote("More beer!", 1_000_000, :update => "empty_bottle")
  end
  
  def test_observe_field
    assert_equal %(<script type=\"text/javascript\">new Form.Element.Observer('glass', 300, function(element, value) {new Ajax.Request('http://www.example.com/reorder_if_empty', {asynchronous:true, evalScripts:true})})</script>),
      observe_field("glass", :frequency => 5.minutes, :url => { :action => "reorder_if_empty" })
  end
  
  def test_observe_form
    assert_equal %(<script type=\"text/javascript\">new Form.Observer('cart', 2, function(element, value) {new Ajax.Request('http://www.example.com/cart_changed', {asynchronous:true, evalScripts:true})})</script>),
      observe_form("cart", :frequency => 2, :url => { :action => "cart_changed" })
  end
  
  def test_auto_complete_field
    assert_equal %(<script type=\"text/javascript\">new Ajax.Autocompleter('some_input', 'some_input_auto_complete', 'http://www.example.com/autocomplete', {})</script>),
      auto_complete_field("some_input", :url => { :action => "autocomplete" });
    assert_equal %(<script type=\"text/javascript\">new Ajax.Autocompleter('some_input', 'some_input_auto_complete', 'http://www.example.com/autocomplete', {tokens:','})</script>),
      auto_complete_field("some_input", :url => { :action => "autocomplete" }, :tokens => ',');
    assert_equal %(<script type=\"text/javascript\">new Ajax.Autocompleter('some_input', 'some_input_auto_complete', 'http://www.example.com/autocomplete', {tokens:[',']})</script>),
      auto_complete_field("some_input", :url => { :action => "autocomplete" }, :tokens => [',']);  
  end
  
  def test_auto_complete_result
    result = [ { :title => 'test1'  }, { :title => 'test2'  } ]
    assert_equal %(<ul><li>test1</li><li>test2</li></ul>), 
      auto_complete_result(result, :title)
    assert_equal %(<ul><li>t<strong class=\"highlight\">est</strong>1</li><li>t<strong class=\"highlight\">est</strong>2</li></ul>), 
      auto_complete_result(result, :title, "est")
  end
  
  def test_text_field_with_auto_complete
    assert_match "<style>",
      text_field_with_auto_complete(:message, :recipient)
    assert_equal %(<input autocomplete=\"off\" id=\"message_recipient\" name=\"message[recipient]\" size=\"30\" type=\"text\" /><div class=\"auto_complete\" id=\"message_recipient_auto_complete\"></div><script type=\"text/javascript\">new Ajax.Autocompleter('message_recipient', 'message_recipient_auto_complete', 'http://www.example.com/auto_complete_for_message_recipient', {})</script>),
      text_field_with_auto_complete(:message, :recipient, {}, :skip_style => true)
  end
  
  def test_effect
    assert_equal "new Effect.Highlight('posts',{});", visual_effect(:highlight, "posts")
    assert_equal "new Effect.Highlight('posts',{});", visual_effect("highlight", :posts)
    assert_equal "new Effect.Highlight('posts',{});", visual_effect(:highlight, :posts)    
    assert_equal "new Effect.Fade('fademe',{duration:4.0});", visual_effect(:fade, "fademe", :duration => 4.0)
    assert_equal "new Effect.Shake(element,{});", visual_effect(:shake)
  end
  
  def test_sortable_element
    assert_equal %(<script type=\"text/javascript\">Sortable.create('mylist', {onUpdate:function(){new Ajax.Request('http://www.example.com/order', {asynchronous:true, evalScripts:true, parameters:Sortable.serialize('mylist')})}})</script>), 
      sortable_element("mylist", :url => { :action => "order" })
    assert_equal %(<script type=\"text/javascript\">Sortable.create('mylist', {constraint:'horizontal', onUpdate:function(){new Ajax.Request('http://www.example.com/order', {asynchronous:true, evalScripts:true, parameters:Sortable.serialize('mylist')})}, tag:'div'})</script>), 
      sortable_element("mylist", :tag => "div", :constraint => "horizontal", :url => { :action => "order" })
    assert_equal %|<script type=\"text/javascript\">Sortable.create('mylist', {constraint:'horizontal', containment:['list1','list2'], onUpdate:function(){new Ajax.Request('http://www.example.com/order', {asynchronous:true, evalScripts:true, parameters:Sortable.serialize('mylist')})}})</script>|, 
      sortable_element("mylist", :containment => ['list1','list2'], :constraint => "horizontal", :url => { :action => "order" })
    assert_equal %(<script type=\"text/javascript\">Sortable.create('mylist', {constraint:'horizontal', containment:'list1', onUpdate:function(){new Ajax.Request('http://www.example.com/order', {asynchronous:true, evalScripts:true, parameters:Sortable.serialize('mylist')})}})</script>), 
      sortable_element("mylist", :containment => 'list1', :constraint => "horizontal", :url => { :action => "order" })
  end
  
  def test_draggable_element
    assert_equal %(<script type=\"text/javascript\">new Draggable('product_13', {})</script>),
      draggable_element('product_13')
    assert_equal %(<script type=\"text/javascript\">new Draggable('product_13', {revert:true})</script>),
      draggable_element('product_13', :revert => true)
  end
  
  def test_drop_receiving_element
    assert_equal %(<script type=\"text/javascript\">Droppables.add('droptarget1', {onDrop:function(element){new Ajax.Request('http://www.example.com/', {asynchronous:true, evalScripts:true, parameters:'id=' + encodeURIComponent(element.id)})}})</script>),
      drop_receiving_element('droptarget1')
    assert_equal %(<script type=\"text/javascript\">Droppables.add('droptarget1', {accept:'products', onDrop:function(element){new Ajax.Request('http://www.example.com/', {asynchronous:true, evalScripts:true, parameters:'id=' + encodeURIComponent(element.id)})}})</script>),
      drop_receiving_element('droptarget1', :accept => 'products')
    assert_equal %(<script type=\"text/javascript\">Droppables.add('droptarget1', {accept:'products', onDrop:function(element){new Ajax.Updater('infobox', 'http://www.example.com/', {asynchronous:true, evalScripts:true, parameters:'id=' + encodeURIComponent(element.id)})}})</script>),
      drop_receiving_element('droptarget1', :accept => 'products', :update => 'infobox')
    assert_equal %(<script type=\"text/javascript\">Droppables.add('droptarget1', {accept:['tshirts','mugs'], onDrop:function(element){new Ajax.Updater('infobox', 'http://www.example.com/', {asynchronous:true, evalScripts:true, parameters:'id=' + encodeURIComponent(element.id)})}})</script>),
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
