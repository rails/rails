require File.dirname(__FILE__) + '/../abstract_unit'
require 'action_controller/url_rewriter'

MockRequest = Struct.new("MockRequest", :protocol, :host, :port, :path, :parameters)
class MockRequest
  def host_with_port
    if (protocol == "http://" && port == 80) || (protocol == "https://" && port == 443)
      host
    else
      host + ":#{port}"
    end
  end
end

class UrlMockFactory
  def self.create(path, parameters)
    ActionController::UrlRewriter.new(
      MockRequest.new("http://", "example.com", 80, path, parameters), 
      parameters["controller"], parameters["action"]
    )
  end
end

class UrlTest < Test::Unit::TestCase
  def setup
    @library_url = ActionController::UrlRewriter.new(MockRequest.new(
      "http://",
      "www.singlefile.com", 
      80,
      "/library/books/ISBN/0743536703/show",
      { "type" => "ISBN", "code" => "0743536703" }
    ), "books", "show")

    @library_url_using_module = ActionController::UrlRewriter.new(MockRequest.new(
      "http://",
      "www.singlefile.com", 
      80,
      "/library/books/ISBN/0743536703/show",
      { "type" => "ISBN", "code" => "0743536703", "module" => "library" }
    ), "books", "show")

    @library_url_on_index = ActionController::UrlRewriter.new(MockRequest.new(
      "http://",
      "www.singlefile.com", 
      80,
      "/library/books/ISBN/0743536703/", 
      { "type" => "ISBN", "code" => "0743536703" }
    ), "books", "index")
    
    @clean_urls = [
      ActionController::UrlRewriter.new(MockRequest.new(
        "http://", "www.singlefile.com", 80, "/identity/", {}
      ), "identity", "index"),
      ActionController::UrlRewriter.new(MockRequest.new(
        "http://", "www.singlefile.com", 80, "/identity", {}
      ), "identity", "index")
    ]

    @clean_url_with_id = ActionController::UrlRewriter.new(MockRequest.new(
      "http://", "www.singlefile.com", 80, "/identity/show/5", { "id" => "5" }
    ), "identity", "show")

    @clean_url_with_same_action_and_controller_name = ActionController::UrlRewriter.new(MockRequest.new(
      "http://", "www.singlefile.com", 80, "/login/login", {  }
    ), "login", "login")

    @clean_url_with_same_action_and_controller_and_module_name = ActionController::UrlRewriter.new(MockRequest.new(
      "http://", "www.singlefile.com", 80, "/login/login/login", { "module" => "login" }
    ), "login", "login")

    @clean_url_with_id_as_char = ActionController::UrlRewriter.new(MockRequest.new(
      "http://", "www.singlefile.com", 80, "/teachers/show/t", { "id" => "t" }
    ), "teachers", "show")
  end

  def test_clean_action
    assert_equal "http://www.singlefile.com/library/books/ISBN/0743536703/edit", @library_url.rewrite(:action => "edit")
  end

  def test_clean_action_to_another_host
    assert_equal(
      "http://www.booksphere.com/library/books/ISBN/0743536703/edit", 
      @library_url.rewrite(:action => "edit", :host => "www.booksphere.com")
    )
  end

  def test_clean_action_to_another_host_and_protocol
    assert_equal(
      "https://www.booksphere.com/library/books/ISBN/0743536703/edit", 
      @library_url.rewrite(:action => "edit", :host => "www.booksphere.com", :protocol => "https://")
    )
  end

  def test_clean_action_with_only_path
    assert_equal "/library/books/ISBN/0743536703/edit", @library_url.rewrite(:action => "edit", :only_path => true)
  end

  def test_action_from_index
    assert_equal "http://www.singlefile.com/library/books/ISBN/0743536703/edit", @library_url_on_index.rewrite(:action => "edit")
  end

  def test_action_from_index_on_clean
    @clean_urls.each do |url|
      assert_equal "http://www.singlefile.com/identity/edit", url.rewrite(:action => "edit")
    end
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

  def test_action_prefix_alone
    assert_equal(
      "http://www.singlefile.com/library/books/XTC/123/",
      @library_url.rewrite(:action_prefix => "XTC/123")
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

  def test_clean_controller_prefix
    assert_equal "http://www.singlefile.com/shop/", @library_url.rewrite(:controller_prefix => "shop")
  end

  def test_clean_controller_with_module
    assert_equal "http://www.singlefile.com/shop/purchases/", @library_url.rewrite(:module => "shop", :controller => "purchases")
  end
  
  def test_getting_out_of_a_module
    assert_equal "http://www.singlefile.com/purchases/", @library_url_using_module.rewrite(:module => false, :controller => "purchases")
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

  def test_controller_and_action_and_empty_overwrite_params_and_anchor
    assert_equal(
      "http://www.singlefile.com/library/settings/show?code=0743536703&type=ISBN#5", 
      @library_url.rewrite(:controller => "settings", :action => "show", :overwrite_params => {},  :anchor => "5")
    )
  end
  
  def test_controller_and_action_and_overwrite_params_and_anchor
    assert_equal(
      "http://www.singlefile.com/library/settings/show?code=0000001&type=ISBN#5", 
      @library_url.rewrite(:controller => "settings", :action => "show", :overwrite_params => {"code"=>"0000001"},  :anchor => "5")
    )
  end

  def test_controller_and_action_and_overwrite_params_with_nil_value_and_anchor
    assert_equal(
      "http://www.singlefile.com/library/settings/show?type=ISBN#5", 
      @library_url.rewrite(:controller => "settings", :action => "show", :overwrite_params => {"code" => nil},  :anchor => "5")
    )
  end

  def test_controller_and_action_params_and_overwrite_params_and_anchor
    assert_equal(
      "http://www.singlefile.com/library/settings/show?code=0000001&version=5.0#5", 
      @library_url.rewrite(:controller => "settings", :action => "show", :params=>{"version" => "5.0"},  :overwrite_params => {"code"=>"0000001"},  :anchor => "5")
    )
  end

  def test_controller_and_action_and_params_anchor
    assert_equal(
      "http://www.singlefile.com/library/settings/show?update=1#5", 
      @library_url.rewrite(:controller => "settings", :action => "show", :params => { "update" => "1"}, :anchor => "5")
    )
  end

  def test_controller_and_index_action
    assert_equal "http://www.singlefile.com/library/settings/", @library_url.rewrite(:controller => "settings", :action => "index")
  end

  def test_same_controller_and_action_names
    assert_equal "http://www.singlefile.com/login/logout", @clean_url_with_same_action_and_controller_name.rewrite(:action => "logout")
  end

  def xtest_same_module_and_controller_and_action_names
    assert_equal "http://www.singlefile.com/login/login/logout", @clean_url_with_same_action_and_controller_and_module_name.rewrite(:action => "logout")
  end

  def test_controller_and_action_with_same_name_as_controller
    @clean_urls.each do |url|
      assert_equal "http://www.singlefile.com/anything/identity", url.rewrite(:controller => "anything", :action => "identity")
    end
  end

  def test_controller_and_index_action_without_controller_prefix
    assert_equal(
      "http://www.singlefile.com/settings/", 
      @library_url.rewrite(:controller => "settings", :action => "index", :controller_prefix => "")
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
      "http://www.singlefile.com/library/books/ISBN/0743536703/show?delete=1&name=David", 
      @library_url.rewrite(:params => {"delete" => "1", "name" => "David"})
    )
  end

  def test_parameters_with_id
    @clean_urls.each do |url|
      assert_equal(
        "http://www.singlefile.com/identity/show?name=David&id=5", 
        url.rewrite(
          :action => "show",
          :params => { "id" => "5", "name" => "David" }
        )
      )
    end
  end

  def test_parameters_with_array
    @clean_urls.each do |url|
      assert_equal(
        "http://www.singlefile.com/identity/show?id[]=3&id[]=5&id[]=10",
	url.rewrite(
		:action => "show",
		:params => { 'id' => [ 3, 5, 10 ] } )
      )
    end
  end

  def test_action_with_id
   assert_equal(
      "http://www.singlefile.com/identity/show/7", 
      @clean_url_with_id.rewrite(
        :action => "show", 
        :id => 7
      )
    )
    @clean_urls.each do |url|
      assert_equal(
        "http://www.singlefile.com/identity/index/7", 
        url.rewrite(:id => 7)
      )
    end
  end

  def test_parameters_with_id_and_away
    assert_equal(
      "http://www.singlefile.com/identity/show/25?name=David", 
      @clean_url_with_id.rewrite(
        :path_params => { "id" => "25" },
        :params => { "name" => "David" }
      )
    )
  end

  def test_parameters_with_index_and_id
    @clean_urls.each do |url|
      assert_equal(
        "http://www.singlefile.com/identity/index/25?name=David", 
        url.rewrite(
          :path_params => { "id" => "25" },
          :params => { "name" => "David" }
        )
      )
    end
  end

  def test_action_going_away_from_id
    assert_equal(
      "http://www.singlefile.com/identity/list", 
      @clean_url_with_id.rewrite(
        :action => "list"
      )
    )
  end

  def test_parameters_with_direct_id_and_away
    assert_equal(
      "http://www.singlefile.com/identity/show/25?name=David", 
      @clean_url_with_id.rewrite(
        :id => "25",
        :params => { "name" => "David" }
      )
    )
  end

  def test_parameters_with_direct_id_and_away
    assert_equal(
      "http://www.singlefile.com/store/open/25?name=David", 
      @clean_url_with_id.rewrite(
        :controller => "store",
        :action => "open",
        :id => "25",
        :params => { "name" => "David" }
      )
    )
  end

  def test_parameters_to_id
    @clean_urls.each do |url|
      %w(show index).each do |action|
        assert_equal(
          "http://www.singlefile.com/identity/#{action}/25?name=David", 
          url.rewrite(
            :action => action,
            :path_params => { "id" => "25" },
            :params => { "name" => "David" }
          )
        )
      end
    end
  end

  def test_parameters_from_id
    assert_equal(
      "http://www.singlefile.com/identity/", 
      @clean_url_with_id.rewrite(
        :action => "index"
      )
    )
  end
  
  def test_id_as_char_and_part_of_controller
    assert_equal(
      "http://www.singlefile.com/teachers/skill/5", 
      @clean_url_with_id_as_char.rewrite(
        :action => "skill",
        :id => 5
      )
    )
  end

  def test_from_clean_to_library
    @clean_urls.each do |url|
      assert_equal(
        "http://www.singlefile.com/library/books/ISBN/0743536703/show?delete=1&name=David", 
        url.rewrite(
          :controller_prefix => "library",
          :controller => "books", 
          :action_prefix => "ISBN/0743536703",
          :action => "show", 
          :params => { "delete" => "1", "name" => "David" }
        )
      )
    end
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
    @library_url = ActionController::UrlRewriter.new(MockRequest.new(
      "http://",
      "www.singlefile.com", 
      8080,
      "/library/books/ISBN/0743536703/show", 
      { "type" => "ISBN", "code" => "0743536703" }
    ), "books", "show")

    assert_equal(
      "http://www.singlefile.com:8080/identity/", 
      @library_url.rewrite(
        :controller => "identity", :controller_prefix => ""
      )
    )
  end
  
  def test_basecamp
    basecamp_url = ActionController::UrlRewriter.new(MockRequest.new(
      "http://",
      "projects.basecamp", 
      80,
      "/clients/disarray/1/msg/transcripts/", 
      {"category_name"=>"transcripts", "client_name"=>"disarray", "action"=>"index", "controller"=>"msg", "project_name"=>"1"}
    ), "msg", "index")
    
    assert_equal(
      "http://projects.basecamp/clients/disarray/1/msg/transcripts/1/comments", 
      basecamp_url.rewrite(:action_prefix => "transcripts/1", :action => "comments")
    )
  end

  def test_on_explicit_index_page # My index page is very modest, thank you...
    url = ActionController::UrlRewriter.new(
      MockRequest.new(
        "http://", "example.com", 80, "/controller/index",
        {"controller"=>"controller", "action"=>"index"}
      ), "controller", "index"
    )
    assert_equal("http://example.com/controller/foo", url.rewrite(:action => 'foo'))
  end

  def test_rewriting_on_similar_fragments
    url = UrlMockFactory.create("/advertisements/advert/", {"controller"=>"advert", "action"=>"index"})
    assert_equal("http://example.com/advertisements/advert/news", url.rewrite(:action => 'news'))
  end

  def test_rewriting_on_similar_fragments_with_action_prefixes
    url = UrlMockFactory.create(
      "/clients/prall/1/msg/all/", 
      { "category_name"=>"all", "client_name"=>"prall", "action"=>"index", "controller"=>"msg", "project_name"=>"1"}
    )

    assert_equal(
      "http://example.com/clients/prall/1/msg/all/new", 
      url.rewrite({ :controller => "msg", :action_prefix => "all", :action => "new" })
    )

    url = UrlMockFactory.create(
      "/clients/prall/1/msg/all/", 
      { "category_name"=>"all", "client_name"=>"prall", "action"=>"index", "controller"=>"msg", "project_name"=>"1"}
    )

    assert_equal(
      "http://example.com/clients/prall/1/msg/allous/new", 
      url.rewrite({ :controller => "msg", :action_prefix => "allous", :action => "new" })
    )
  end

  def test_clean_application_prefix
    assert_equal "http://www.singlefile.com/namespace/library/books/ISBN/0743536703/show",
      @library_url.rewrite(:application_prefix => "/namespace")
  end

  def test_clean_application_prefix_with_controller_prefix
    assert_equal "http://www.singlefile.com/namespace/shop/",
      @library_url.rewrite(:application_prefix => "/namespace",
                           :controller_prefix => "shop" )
  end

  def test_blank_application_prefix
    assert_equal "http://www.singlefile.com/library/books/ISBN/0743536703/show",
      @library_url.rewrite(:application_prefix => "")
  end

  def test_nil_application_prefix
    assert_equal "http://www.singlefile.com/library/books/ISBN/0743536703/show",
      @library_url.rewrite(:application_prefix => nil)
  end
end
