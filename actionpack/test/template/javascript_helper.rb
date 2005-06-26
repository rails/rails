require File.dirname(__FILE__) + '/../abstract_unit'

class JavascriptHelperTest < Test::Unit::TestCase
  include ActionView::Helpers::JavascriptHelper
  
  include ActionView::Helpers::UrlHelper
  include ActionView::Helpers::TagHelper
  
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
    assert_not_nil define_javascript_functions.split("\n")[1].match(/Prototype: an object-oriented Javascript library/)
  end

  def test_escape_javascript
    assert_equal %(This \\"thing\\" is really\\n netos\\'), escape_javascript(%(This "thing" is really\n netos'))
  end
  
  def test_link_to_function
    assert_equal %(<a href="#" onclick="alert('Hello world!'); return false;">Greeting</a>), 
      link_to_function("Greeting", "alert('Hello world!')")
  end
  
  def test_link_to_remote
    assert_equal %(<a class="fine" href="#" onclick="new Ajax.Request('http://www.example.com/whatnot', {asynchronous:true}); return false;">Remote outpost</a>),
      link_to_remote("Remote outpost", { :url => { :action => "whatnot"  }}, { :class => "fine"  })
    assert_equal %(<a href="#" onclick="new Ajax.Request('http://www.example.com/whatnot', {onComplete:function(request){alert(request.reponseText)}, asynchronous:true}); return false;">Remote outpost</a>),
      link_to_remote("Remote outpost", :complete => "alert(request.reponseText)", :url => { :action => "whatnot"  })
  end
  
  def test_periodically_call_remote
    assert_equal %(<script>new PeriodicalExecuter(function() {new Ajax.Updater('schremser_bier', 'http://www.example.com/mehr_bier', {asynchronous:true})}, 10)</script>),
      periodically_call_remote(:update => "schremser_bier", :url => { :action => "mehr_bier" })
  end
  
  def test_form_remote_tag
    assert_equal %(<form action="http://www.example.com/fast" method="post" onsubmit="new Ajax.Updater('glass_of_beer', 'http://www.example.com/fast', {parameters:Form.serialize(this), asynchronous:true}); return false;">),
      form_remote_tag(:update => "glass_of_beer", :url => { :action => :fast  })
  end
  
  def test_submit_to_remote
    assert_equal %(<input name="More beer!" onclick="new Ajax.Updater('empty_bottle', 'http://www.example.com/', {parameters:Form.serialize(this.form), asynchronous:true}); return false;" type="button" value="1000000" />),
      submit_to_remote("More beer!", 1_000_000, :update => "empty_bottle")
  end
  
  def test_observe_field
    assert_equal %(<script type="text/javascript">new Form.Element.Observer('glass', 300, function(element, value) {new Ajax.Request('http://www.example.com/reorder_if_empty', {asynchronous:true})})</script>),
      observe_field("glass", :frequency => 5.minutes, :url => { :action => "reorder_if_empty" })
  end
  
  def test_observe_form
    assert_equal %(<script type="text/javascript">new Form.Observer('cart', 2, function(element, value) {new Ajax.Request('http://www.example.com/cart_changed', {asynchronous:true})})</script>),
      observe_form("cart", :frequency => 2, :url => { :action => "cart_changed" })
  end
  
  def test_remote_autocomplete
    assert_equal %(<script type="text/javascript">new Ajax.Autocompleter('some_input', 'some_input_autocomplete', 'http://www.example.com/autocomplete', {})</script>),
      remote_autocomplete("some_input", :url => { :action => "autocomplete" });    
  end 
  
  def test_effect
    assert_equal "new Effect.Highlight('posts',{});", visual_effect(:highlight, "posts")
    assert_equal "new Effect.Highlight('posts',{});", visual_effect("highlight", :posts)
    assert_equal "new Effect.Highlight('posts',{});", visual_effect(:highlight, :posts)    
    assert_equal "new Effect.Fade('fademe',{duration:4.0});", visual_effect(:fade, "fademe", :duration => 4.0)
  end
  
  def test_remote_sortable
    assert_equal %(<script type="text/javascript">Sortable.create('mylist',{onUpdate:function(){new Ajax.Request('http://www.example.com/order', {parameters:Sortable.serialize('mylist'), asynchronous:true})}})</script>), 
      remote_sortable("mylist", :url => { :action => "order" })
  end
  
end
