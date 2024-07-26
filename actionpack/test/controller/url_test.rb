require File.dirname(__FILE__) + '/../abstract_unit'
require 'action_controller/url_rewriter'

class UrlTest < Test::Unit::TestCase
  def setup
    @library_url = ActionController::UrlRewriter.new(
      "http://",
      "www.singlefile.com", 
      80,
      "/library/books/ISBN/0743536703/show", 
      "books", "show", { "type" => "ISBN", "code" => "0743536703" }
    )

    @library_url_on_index = ActionController::UrlRewriter.new(
      "http://",
      "www.singlefile.com", 
      80,
      "/library/books/ISBN/0743536703/", 
      "books", "index", { "type" => "ISBN", "code" => "0743536703" }
    )
    
    @clean_url = ActionController::UrlRewriter.new(
      "http://", "www.singlefile.com", 80, "/identity/", "identity", "index", {}
    )

    @clean_url_with_id = ActionController::UrlRewriter.new(
      "http://", "www.singlefile.com", 80, "/identity/show/5", "identity", "show", { "id" => "5" }
    )
  end

  def test_clean_action
    assert_equal "http://www.singlefile.com/library/books/ISBN/0743536703/edit", @library_url.rewrite(:action => "edit")
  end

  def test_action_from_index
    assert_equal "http://www.singlefile.com/library/books/ISBN/0743536703/edit", @library_url_on_index.rewrite(:action => "edit")
  end
  
  def test_action_from_index_on_clean
    assert_equal "http://www.singlefile.com/identity/edit", @clean_url.rewrite(:action => "edit")
  end

  def test_action_without_prefix
    assert_equal "http://www.singlefile.com/library/books/", @library_url.rewrite(:action => "index", :action_prefix => "")
  end

  def test_action_with_prefix
    assert_equal(
      "http://www.singlefile.com/library/books/XTC/123/show", 
      @library_url.rewrite(:action => "show", :action_prefix => "XTC/123")
    )
  end

  def test_action_with_suffix
    assert_equal(
      "http://www.singlefile.com/library/books/show/XTC/123",
      @library_url.rewrite(:action => "show", :action_prefix => "", :action_suffix => "XTC/123")
    )
  end

  def test_clean_controller
    assert_equal "http://www.singlefile.com/library/settings/", @library_url.rewrite(:controller => "settings")
  end
  
  def test_controller_and_action
    assert_equal "http://www.singlefile.com/library/settings/show", @library_url.rewrite(:controller => "settings", :action => "show")
  end

  def test_controller_and_action_and_anchor
    assert_equal(
      "http://www.singlefile.com/library/settings/show#5", 
      @library_url.rewrite(:controller => "settings", :action => "show", :anchor => "5")
    )
  end

  def test_controller_and_index_action
    assert_equal "http://www.singlefile.com/library/settings/", @library_url.rewrite(:controller => "settings", :action => "index")
  end

  def test_controller_and_index_action_without_controller_prefix
    assert_equal(
      "http://www.singlefile.com/settings/", 
      @library_url.rewrite(:controller => "settings", :action => "index", :controller_prefix => "")
    )
  end

  def test_action_with_controller_prefix
    assert_equal(
      "http://www.singlefile.com/fantastic/books/ISBN/0743536703/edit", 
      @library_url.rewrite(:controller_prefix => "fantastic", :action => "edit")
    )
  end

  def test_controller_and_index_action_with_controller_prefix
    assert_equal(
      "http://www.singlefile.com/fantastic/settings/show", 
      @library_url.rewrite(:controller => "settings", :action => "show", :controller_prefix => "fantastic")
    )
  end

  def test_path_parameters
    assert_equal "http://www.singlefile.com/library/books/EXBC/0743536703/show", @library_url.rewrite(:path_params => {"type" => "EXBC"})
  end
  
  def test_parameters
    assert_equal(
      "http://www.singlefile.com/library/books/ISBN/0743536703/show?name=David&delete=1", 
      @library_url.rewrite(:params => {"delete" => "1", "name" => "David"})
    )
  end

  def test_parameters_with_id
    assert_equal(
      "http://www.singlefile.com/identity/show/5?name=David", 
      @clean_url.rewrite(
        :action => "show", 
        :params => {"id" => "5", "name" => "David"}
      )
    )
  end

  def test_parameters_with_id_and_away
    assert_equal(
      "http://www.singlefile.com/identity/show/25?name=David", 
      @clean_url_with_id.rewrite(
        :path_params => {"id" => "25" },
        :params => { "name" => "David"}
      )
    )
  end

  def test_parameters_with_direct_id_and_away
    assert_equal(
      "http://www.singlefile.com/identity/show/25?name=David", 
      @clean_url_with_id.rewrite(
        :id => "25",
        :params => { "name" => "David"}
      )
    )
  end

  def test_parameters_to_id
    assert_equal(
      "http://www.singlefile.com/identity/show/25?name=David", 
      @clean_url.rewrite(
        :action => "show",
        :path_params => {"id" => "25" },
        :params => { "name" => "David"}
      )
    )
  end

  def test_parameters_from_id
    assert_equal(
      "http://www.singlefile.com/identity/", 
      @clean_url_with_id.rewrite(
        :action => "index"
      )
    )
  end
  
  def test_from_clean_to_libray
    assert_equal(
      "http://www.singlefile.com/library/books/ISBN/0743536703/show?name=David&delete=1", 
      @clean_url.rewrite(
        :controller_prefix => "library",
        :controller => "books", 
        :action_prefix => "ISBN/0743536703",
        :action => "show", 
        :params => {"delete" => "1", "name" => "David"}
      )
    )
  end
  
  def test_from_library_to_clean
    assert_equal(
      "http://www.singlefile.com/identity/", 
      @library_url.rewrite(
        :controller => "identity", :controller_prefix => ""
      )
    )
  end
  
  def test_from_another_port
    @library_url = ActionController::UrlRewriter.new(
      "http://",
      "www.singlefile.com", 
      8080,
      "/library/books/ISBN/0743536703/show", 
      "books", "show", { "type" => "ISBN", "code" => "0743536703" }
    )

    assert_equal(
      "http://www.singlefile.com:8080/identity/", 
      @library_url.rewrite(
        :controller => "identity", :controller_prefix => ""
      )
    )
  end
end