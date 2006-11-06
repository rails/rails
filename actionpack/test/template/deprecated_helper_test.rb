require File.dirname(__FILE__) + '/../abstract_unit'

class DeprecatedHelperTest < Test::Unit::TestCase
  include ActionView::Helpers::JavaScriptHelper
  include ActionView::Helpers::CaptureHelper
  
  def test_update_element_function
    assert_deprecated 'update_element_function' do
      
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

end

