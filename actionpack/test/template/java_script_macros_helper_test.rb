require File.dirname(__FILE__) + '/../abstract_unit'

class JavaScriptMacrosHelperTest < Test::Unit::TestCase
  include ActionView::Helpers::JavaScriptHelper
  include ActionView::Helpers::JavaScriptMacrosHelper
  
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


  def test_auto_complete_field
    assert_dom_equal %(<script type=\"text/javascript\">\n//<![CDATA[\nvar some_input_auto_completer = new Ajax.Autocompleter('some_input', 'some_input_auto_complete', 'http://www.example.com/autocomplete', {})\n//]]>\n</script>),
      auto_complete_field("some_input", :url => { :action => "autocomplete" });
    assert_dom_equal %(<script type=\"text/javascript\">\n//<![CDATA[\nvar some_input_auto_completer = new Ajax.Autocompleter('some_input', 'some_input_auto_complete', 'http://www.example.com/autocomplete', {tokens:','})\n//]]>\n</script>),
      auto_complete_field("some_input", :url => { :action => "autocomplete" }, :tokens => ',');
    assert_dom_equal %(<script type=\"text/javascript\">\n//<![CDATA[\nvar some_input_auto_completer = new Ajax.Autocompleter('some_input', 'some_input_auto_complete', 'http://www.example.com/autocomplete', {tokens:[',']})\n//]]>\n</script>),
      auto_complete_field("some_input", :url => { :action => "autocomplete" }, :tokens => [',']);  
    assert_dom_equal %(<script type=\"text/javascript\">\n//<![CDATA[\nvar some_input_auto_completer = new Ajax.Autocompleter('some_input', 'some_input_auto_complete', 'http://www.example.com/autocomplete', {minChars:3})\n//]]>\n</script>),
      auto_complete_field("some_input", :url => { :action => "autocomplete" }, :min_chars => 3);
    assert_dom_equal %(<script type=\"text/javascript\">\n//<![CDATA[\nvar some_input_auto_completer = new Ajax.Autocompleter('some_input', 'some_input_auto_complete', 'http://www.example.com/autocomplete', {onHide:function(element, update){alert('me');}})\n//]]>\n</script>),
      auto_complete_field("some_input", :url => { :action => "autocomplete" }, :on_hide => "function(element, update){alert('me');}");
    assert_dom_equal %(<script type=\"text/javascript\">\n//<![CDATA[\nvar some_input_auto_completer = new Ajax.Autocompleter('some_input', 'some_input_auto_complete', 'http://www.example.com/autocomplete', {frequency:2})\n//]]>\n</script>),
      auto_complete_field("some_input", :url => { :action => "autocomplete" }, :frequency => 2);
    assert_dom_equal %(<script type=\"text/javascript\">\n//<![CDATA[\nvar some_input_auto_completer = new Ajax.Autocompleter('some_input', 'some_input_auto_complete', 'http://www.example.com/autocomplete', {afterUpdateElement:function(element,value){alert('You have chosen: '+value)}})\n//]]>\n</script>),
      auto_complete_field("some_input", :url => { :action => "autocomplete" }, 
        :after_update_element => "function(element,value){alert('You have chosen: '+value)}");
    assert_dom_equal %(<script type=\"text/javascript\">\n//<![CDATA[\nvar some_input_auto_completer = new Ajax.Autocompleter('some_input', 'some_input_auto_complete', 'http://www.example.com/autocomplete', {paramName:'huidriwusch'})\n//]]>\n</script>),
      auto_complete_field("some_input", :url => { :action => "autocomplete" }, :param_name => 'huidriwusch');
  end
  
  def test_auto_complete_result
    result = [ { :title => 'test1'  }, { :title => 'test2'  } ]
    assert_equal %(<ul><li>test1</li><li>test2</li></ul>), 
      auto_complete_result(result, :title)
    assert_equal %(<ul><li>t<strong class=\"highlight\">est</strong>1</li><li>t<strong class=\"highlight\">est</strong>2</li></ul>), 
      auto_complete_result(result, :title, "est")
    
    resultuniq = [ { :title => 'test1'  }, { :title => 'test1'  } ]
    assert_equal %(<ul><li>t<strong class=\"highlight\">est</strong>1</li></ul>), 
      auto_complete_result(resultuniq, :title, "est")
  end
  
  def test_text_field_with_auto_complete
    assert_match %(<style type="text/css">),
      text_field_with_auto_complete(:message, :recipient)

    assert_dom_equal %(<input id=\"message_recipient\" name=\"message[recipient]\" size=\"30\" type=\"text\" /><div class=\"auto_complete\" id=\"message_recipient_auto_complete\"></div><script type=\"text/javascript\">\n//<![CDATA[\nvar message_recipient_auto_completer = new Ajax.Autocompleter('message_recipient', 'message_recipient_auto_complete', 'http://www.example.com/auto_complete_for_message_recipient', {})\n//]]>\n</script>),
      text_field_with_auto_complete(:message, :recipient, {}, :skip_style => true)
  end
  
  def test_in_place_editor_external_control
      assert_dom_equal %(<script type=\"text/javascript\">\n//<![CDATA[\nnew Ajax.InPlaceEditor('some_input', 'http://www.example.com/inplace_edit', {externalControl:'blah'})\n//]]>\n</script>),
        in_place_editor('some_input', {:url => {:action => 'inplace_edit'}, :external_control => 'blah'})
  end
  
  def test_in_place_editor_size
      assert_dom_equal %(<script type=\"text/javascript\">\n//<![CDATA[\nnew Ajax.InPlaceEditor('some_input', 'http://www.example.com/inplace_edit', {size:4})\n//]]>\n</script>),
        in_place_editor('some_input', {:url => {:action => 'inplace_edit'}, :size => 4})
  end
  
  def test_in_place_editor_cols_no_rows
      assert_dom_equal %(<script type=\"text/javascript\">\n//<![CDATA[\nnew Ajax.InPlaceEditor('some_input', 'http://www.example.com/inplace_edit', {cols:4})\n//]]>\n</script>),
        in_place_editor('some_input', {:url => {:action => 'inplace_edit'}, :cols => 4})
  end
  
  def test_in_place_editor_cols_with_rows
      assert_dom_equal %(<script type=\"text/javascript\">\n//<![CDATA[\nnew Ajax.InPlaceEditor('some_input', 'http://www.example.com/inplace_edit', {cols:40, rows:5})\n//]]>\n</script>),
        in_place_editor('some_input', {:url => {:action => 'inplace_edit'}, :rows => 5, :cols => 40})
  end

  def test_inplace_editor_loading_text
      assert_dom_equal %(<script type=\"text/javascript\">\n//<![CDATA[\nnew Ajax.InPlaceEditor('some_input', 'http://www.example.com/inplace_edit', {loadingText:'Why are we waiting?'})\n//]]>\n</script>),
        in_place_editor('some_input', {:url => {:action => 'inplace_edit'}, :loading_text => 'Why are we waiting?'})
  end
  
  def test_in_place_editor_url
    assert_match "Ajax.InPlaceEditor('id-goes-here', 'http://www.example.com/action_to_set_value')",
    in_place_editor( 'id-goes-here', :url => { :action => "action_to_set_value" })    
  end
  
  def test_in_place_editor_load_text_url
    assert_match "Ajax.InPlaceEditor('id-goes-here', 'http://www.example.com/action_to_set_value', {loadTextURL:'http://www.example.com/action_to_get_value'})",
    in_place_editor( 'id-goes-here', 
      :url => { :action => "action_to_set_value" }, 
      :load_text_url => { :action => "action_to_get_value" })
  end
  
  def test_in_place_editor_eval_scripts
    assert_match "Ajax.InPlaceEditor('id-goes-here', 'http://www.example.com/action_to_set_value', {evalScripts:true})",
    in_place_editor( 'id-goes-here', 
      :url => { :action => "action_to_set_value" }, 
      :script => true )
  end
  
end
