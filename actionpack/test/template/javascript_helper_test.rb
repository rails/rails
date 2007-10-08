require File.dirname(__FILE__) + '/../abstract_unit'

class JavaScriptHelperTest < Test::Unit::TestCase
  include ActionView::Helpers::JavaScriptHelper
  
  include ActionView::Helpers::UrlHelper
  include ActionView::Helpers::TagHelper
  include ActionView::Helpers::TextHelper
  include ActionView::Helpers::FormHelper
  include ActionView::Helpers::CaptureHelper
  
  def test_define_javascript_functions
    # check if prototype.js is included first
    assert_not_nil define_javascript_functions.split("\n")[1].match(/Prototype JavaScript framework/)
    
    # check that scriptaculous.js is not in here, only needed if loaded remotely
    assert_nil define_javascript_functions.split("\n")[1].match(/var Scriptaculous = \{/)
  end

  def test_escape_javascript
    assert_equal %(This \\"thing\\" is really\\n netos\\'), escape_javascript(%(This "thing" is really\n netos'))
    assert_equal %(backslash\\\\test), escape_javascript( %(backslash\\test) )
  end
                                      
  def test_link_to_function
    assert_dom_equal %(<a href="#" onclick="alert('Hello world!'); return false;">Greeting</a>), 
      link_to_function("Greeting", "alert('Hello world!')")
  end
  
  def test_link_to_function_with_existing_onclick
    assert_dom_equal %(<a href="#" onclick="confirm('Sanity!'); alert('Hello world!'); return false;">Greeting</a>), 
      link_to_function("Greeting", "alert('Hello world!')", :onclick => "confirm('Sanity!')")
  end

  def test_link_to_function_with_rjs_block
    html = link_to_function( "Greet me!" ) do |page|
      page.replace_html 'header', "<h1>Greetings</h1>"
    end
    assert_dom_equal %q(<a href="#" onclick="Element.update(&quot;header&quot;, &quot;\074h1\076Greetings\074/h1\076&quot;);; return false;">Greet me!</a>), html
  end

  def test_link_to_function_with_rjs_block_and_options
    html = link_to_function( "Greet me!", :class => "updater" ) do |page|
      page.replace_html 'header', "<h1>Greetings</h1>"
    end
    assert_dom_equal %q(<a href="#" class="updater" onclick="Element.update(&quot;header&quot;, &quot;\074h1\076Greetings\074/h1\076&quot;);; return false;">Greet me!</a>), html
  end

  def test_button_to_function
    assert_dom_equal %(<input type="button" onclick="alert('Hello world!');" value="Greeting" />), 
      button_to_function("Greeting", "alert('Hello world!')")
  end

  def test_button_to_function_with_rjs_block
    html = button_to_function( "Greet me!" ) do |page|
      page.replace_html 'header', "<h1>Greetings</h1>"
    end
    assert_dom_equal %q(<input type="button" onclick="Element.update(&quot;header&quot;, &quot;\074h1\076Greetings\074/h1\076&quot;);;" value="Greet me!" />), html
  end

  def test_button_to_function_with_rjs_block_and_options
    html = button_to_function( "Greet me!", :class => "greeter" ) do |page|
      page.replace_html 'header', "<h1>Greetings</h1>"
    end
    assert_dom_equal %q(<input type="button" class="greeter" onclick="Element.update(&quot;header&quot;, &quot;\074h1\076Greetings\074/h1\076&quot;);;" value="Greet me!" />), html
  end
end
