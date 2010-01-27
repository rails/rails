require 'abstract_unit'
require 'active_model'

class Author
  extend ActiveModel::Naming
  include ActiveModel::Conversion

  attr_reader :id
  def save
    @id = 1 
  end
  
  def new_record?
    @id.nil? 
  end

  def name
    @id.nil? ? 'new author' : "author ##{@id}"
  end
end

class Article
  extend ActiveModel::Naming
  include ActiveModel::Conversion
  attr_reader :id
  attr_reader :author_id

  def save 
    @id = 1 
    @author_id = 1 
  end

  def new_record?
    @id.nil? 
  end

  def name
    @id.nil? ? 'new article' : "article ##{@id}"
  end
end

class AjaxHelperBaseTest < ActionView::TestCase
  attr_accessor :formats, :output_buffer

  def reset_formats(format)
    @format = format
  end

  def setup
    super
    @template = self
    @controller = Class.new do
        
      def url_for(options)
        return optons unless options.is_a?(Hash)

        url = options.delete(:only_path) ? '/' : 'http://www.example.com'
        
        if controller = options.delete(:controller)
          url << '/' << controller.to_s
        end
        if action = options.delete(:action)
          url << '/' << action.to_s
        end

        if id = options.delete(:id)
          url << '/' << id.to_s
        end
        
        url << hash_to_param(options) if options.any? 

        url.gsub!(/\/\/+/,'/')

        url
      end

      private 
        def hash_to_param(hash)
          hash.map { |k,v| "#{k}=#{v}" }.join('&').insert(0,'?')
        end
    end.new
  end

  protected
    def request_forgery_protection_token
      nil
    end

    def protect_against_forgery?
      false
    end
end

class AjaxHelperTest < AjaxHelperBaseTest
  def _evaluate_assigns_and_ivars() end

  def setup
    @record = @author = Author.new
    @article = Article.new
    super
  end

  test "link_to_remote" do
    assert_dom_equal %(<a class=\"fine\" href=\"#\" data-remote=\"true\" data-url=\"/whatnot\">Remove Author</a>),
      link_to_remote("Remove Author", { :url => { :action => "whatnot" }}, { :class => "fine"  })
    assert_dom_equal %(<a href=\"#\" data-remote=\"true\" data-url=\"/whatnot\" data-oncomplete=\"alert(request.responseText)\">Remove Author</a>),
      link_to_remote("Remove Author", :complete => "alert(request.responseText)", :url => { :action => "whatnot"  })
    assert_dom_equal %(<a href=\"#\" data-remote=\"true\" data-url=\"/whatnot\" data-onsuccess=\"alert(request.responseText)\">Remove Author</a>),
      link_to_remote("Remove Author", :success => "alert(request.responseText)", :url => { :action => "whatnot"  })
    assert_dom_equal %(<a href=\"#\" data-remote=\"true\" data-url=\"/whatnot\" data-onfailure=\"alert(request.responseText)\">Remove Author</a>),
      link_to_remote("Remove Author", :failure => "alert(request.responseText)", :url => { :action => "whatnot"  })
    assert_dom_equal %(<a href=\"#\" data-remote=\"true\" data-url=\"/whatnot?a=10&amp;b=20\" data-onfailure=\"alert(request.responseText)\">Remove Author</a>),
      link_to_remote("Remove Author", :failure => "alert(request.responseText)", :url => { :action => "whatnot", :a => '10', :b => '20' })
    assert_dom_equal %(<a href=\"#\" data-remote=\"true\" data-url=\"/whatnot\" data-remote-type=\"synchronous\">Remove Author</a>),
      link_to_remote("Remove Author", :url => { :action => "whatnot" }, :type => :synchronous)
    assert_dom_equal %(<a href=\"#\" data-remote=\"true\" data-url=\"/whatnot\" data-update-position=\"bottom\">Remove Author</a>),
      link_to_remote("Remove Author", :url => { :action => "whatnot" }, :position => :bottom)
  end

  test "link_to_remote with url and oncomplete" do
    actual = link_to_remote "undo", :url => { :controller => "words", :action => "undo", :n => 5 }, :complete => "undoRequestCompleted(request)"
    expected = '<a href="#" data-url="/words/undo?n=5" data-remote="true" data-oncomplete="undoRequestCompleted(request)">undo</a>'
    assert_dom_equal expected, actual
  end

  test "link_to_remote with delete" do
    actual = link_to_remote("Remove Author", { :url => { :action => "whatnot" }, :method => 'delete'}, { :class => "fine" })
    expected = '<a class="fine" rel="nofollow" href="#" data-remote="true" data-method="delete" data-url="/whatnot">Remove Author</a>'
    assert_dom_equal expected, actual
  end
  
  test "link_to_remote using both url and href" do
      expected = '<a href="/destroy" data-url="/destroy" data-update-success="posts" data-remote="true">Delete this Post</a>'
      assert_dom_equal expected, link_to_remote( "Delete this Post",
                                                  { :update => "posts",   
                                                    :url    => { :action => "destroy" } },
                                                    :href   => url_for(:action => "destroy"))
  end

  test "link_to_remote with update-success and url" do
    expected = '<a href="#" data-url="/destroy" data-update-success="posts" data-update-failure="error" data-remote="true">Delete this Post</a>'
    assert_dom_equal expected, link_to_remote( "Delete this Post", :url    => { :action => "destroy"},
                                                                   :update => { :success => "posts", :failure => "error" })
  end

  test "link_to_remote with before/after callbacks" do
    assert_dom_equal %(<a href=\"#\" data-remote=\"true\" data-url=\"/whatnot\" data-onbefore=\"before();\" data-onafter=\"after();\">Remote outauthor</a>),
      link_to_remote("Remote outauthor", :url => { :action => "whatnot" }, :before => "before();", :after => "after();")
  end
  
  test "link_to_remote using :with expression" do
    expected = %(<a href=\"#\" data-remote=\"true\" data-url=\"/whatnot\" data-with=\"id=123\">Remote outauthor</a>)
    assert_dom_equal expected, link_to_remote("Remote outauthor", :url => { :action => "whatnot" }, :with => "id=123")
  end

  test "link_to_remote using :condition expression" do
    expected = %(<a href=\"#\" data-remote=\"true\" data-url=\"/whatnot\" data-condition=\"$('foo').val() == true\">Remote outauthor</a>)
    assert_dom_equal expected, link_to_remote("Remote outauthor", :url => { :action => "whatnot" }, :condition => '$(\'foo\').val() == true')
  end

  test "link_to_remote using explicit :href" do
    expected = %(<a href=\"http://www.example.com/testhref\" data-remote=\"true\" data-url=\"/whatnot\" data-condition=\"$('foo').val() == true\">Remote outauthor</a>)
    assert_dom_equal expected, link_to_remote("Remote outauthor", {:url => { :action => "whatnot" }, :condition => '$(\'foo\').val() == true'}, :href => 'http://www.example.com/testhref')
  end

  test "link_to_remote using :submit" do
    expected = %(<a href=\"#\" data-remote=\"true\" data-url=\"/whatnot\" data-submit=\"myForm\">Remote outauthor</a>)
    assert_dom_equal expected, link_to_remote("Remote outauthor", :url => { :action => "whatnot" }, :submit => 'myForm')
  end

  test "link_to_remote with method delete" do
    assert_dom_equal %(<a class=\"fine\" href=\"#\" data-remote=\"true\" data-url=\"/whatnot\" data-method=\"delete\" rel=\"nofollow\">Remote outauthor</a>),
      link_to_remote("Remote outauthor", { :url => { :action => "whatnot" }, :method => "delete"}, { :class => "fine"  })
  end

  test "link_to_remote with method delete as symbol" do
    assert_dom_equal %(<a class=\"fine\" href=\"#\" data-remote=\"true\" data-url=\"/whatnot\" data-method=\"delete\" rel=\"nofollow\">Remote outauthor</a>),
      link_to_remote("Remote outauthor", { :url => { :action => "whatnot" }, :method => :delete}, { :class => "fine"  })
  end

  test "link_to_remote html options" do
    assert_dom_equal %(<a class=\"fine\" href=\"#\" data-remote=\"true\" data-url=\"/whatnot\">Remote outauthor</a>),
      link_to_remote("Remote outauthor", { :url => { :action => "whatnot"  }, :html => { :class => "fine" } })
  end

  test "link_to_remote url quote escaping" do
    assert_dom_equal %(<a href="#" data-remote=\"true\" data-url=\"/whatnot\\\'s\">Remote</a>),
      link_to_remote("Remote", { :url => { :action => "whatnot's" } })
  end

  test "link_to_remote with confirm" do
    assert_dom_equal %(<a class=\"fine\" href=\"#\" data-remote=\"true\" data-url=\"/whatnot\" data-method=\"delete\" rel=\"nofollow\" data-confirm="Are you sure?">Remote confirm</a>),
      link_to_remote("Remote confirm", { :url => { :action => "whatnot" }, :method => "delete", :confirm => "Are you sure?"}, { :class => "fine"  })
  end

  test "button_to_remote" do
    assert_dom_equal %(<input class=\"fine\" type=\"button\" value=\"Remote outpost\" data-remote=\"true\" data-url=\"/whatnot\" />),
      button_to_remote("Remote outpost", { :url => { :action => "whatnot" }}, { :class => "fine"  })
    assert_dom_equal %(<input type=\"button\" value=\"Remote outpost\" data-remote=\"true\" data-url=\"/whatnot\" data-oncomplete=\"alert(request.reponseText)\" />),
      button_to_remote("Remote outpost", :complete => "alert(request.reponseText)", :url => { :action => "whatnot"  })
    assert_dom_equal %(<input type=\"button\" value=\"Remote outpost\" data-remote=\"true\" data-url=\"/whatnot\" data-onsuccess=\"alert(request.reponseText)\" />),
      button_to_remote("Remote outpost", :success => "alert(request.reponseText)", :url => { :action => "whatnot"  })
    assert_dom_equal %(<input type=\"button\" value=\"Remote outpost\" data-remote=\"true\" data-url=\"/whatnot\" data-onfailure=\"alert(request.reponseText)\" />),
      button_to_remote("Remote outpost", :failure => "alert(request.reponseText)", :url => { :action => "whatnot"  })
    assert_dom_equal %(<input type=\"button\" value=\"Remote outpost\" data-remote=\"true\" data-url=\"/whatnot?a=10&amp;b=20\" data-onfailure=\"alert(request.reponseText)\" />),
      button_to_remote("Remote outpost", :failure => "alert(request.reponseText)", :url => { :action => "whatnot", :a => '10', :b => '20' })
  end

  test "button_to_remote with confirm" do
    assert_dom_equal %(<input class=\"fine\" type=\"button\" value=\"Remote outpost\" data-remote=\"true\" data-url=\"/whatnot\" data-confirm="Are you sure?" />),
      button_to_remote("Remote outpost", { :url => { :action => "whatnot" }, :confirm => "Are you sure?"}, { :class => "fine"  })
  end

  test "button_to_remote with :submit" do
    assert_dom_equal %(<input class=\"fine\" type=\"button\" value=\"Remote outpost\" data-remote=\"true\" data-url=\"/whatnot\" data-submit="myForm" />),
      button_to_remote("Remote outpost", { :url => { :action => "whatnot" }, :submit => "myForm"}, { :class => "fine"  })
  end

  test "periodically_call_remote" do
    expected = "<script data-url='/mehr_bier' data-update-success='schremser_bier' type='application/json' data-frequency='10' data-periodical='true'></script>"
    actual = periodically_call_remote(:update => "schremser_bier", :url => { :action => "mehr_bier" })
    assert_dom_equal expected, actual 
  end

  test "periodically_call_remote_with_frequency" do
    expected = "<script data-periodical='true' type='application/json' data-frequency='2'></script>"
    actual   = periodically_call_remote(:frequency => 2)
    assert_dom_equal expected, actual 
  end

  test "periodically_call_remote_with_function" do
    expected = "<script data-periodical=\"true\" type=\"application/json\" data-onobserve=\"alert('test')\" data-frequency='2'></script>"
    actual   = periodically_call_remote(:frequency => 2, :function => "alert('test')")
    assert_dom_equal expected, actual
  end

  test "periodically_call_remote_with_update" do
     actual = periodically_call_remote(:url => { :action => 'get_averages' }, :update => 'avg')
     expected = "<script data-periodical='true' data-url='/get_averages' type='application/json' data-update-success='avg' data-frequency='10'></script>" 
     assert_dom_equal expected, actual
  end

  test "periodically_call_remote with update success and failure" do
    actual = periodically_call_remote(:url => { :action => 'invoice', :id => 1 },:update => { :success => "invoice", :failure => "error" })
    expected = "<script data-periodical='true' data-url='/invoice/1' type='application/json' data-update-success='invoice' data-frequency='10' data-update-failure='error'></script>"
    assert_dom_equal expected, actual
  end

  test "periodically_call_remote with frequency and update" do
    actual = periodically_call_remote(:url => 'update', :frequency => '20', :update => 'news_block')
    expected = "<script data-periodical='true' data-url='update' type='application/json' data-update-success='news_block' data-frequency='20'></script>"
    assert_dom_equal expected, actual
  end

  test "form_remote_tag" do
    assert_dom_equal %(<form action=\"/fast\" method=\"post\" data-remote=\"true\" data-update-success=\"glass_of_beer\">),
      form_remote_tag(:update => "glass_of_beer", :url => { :action => :fast  } ) 
    assert_dom_equal %(<form action=\"/fast\" method=\"post\" data-remote=\"true\" data-update-success=\"glass_of_beer\">),
      form_remote_tag(:update => { :success => "glass_of_beer" }, :url => { :action => :fast  })
    assert_dom_equal %(<form action=\"/fast\" method=\"post\" data-remote=\"true\" data-update-failure=\"glass_of_water\">),
      form_remote_tag(:update => { :failure => "glass_of_water" }, :url => { :action => :fast  })
    assert_dom_equal %(<form action=\"/fast\" method=\"post\" data-remote=\"true\" data-update-success=\"glass_of_beer\" data-update-failure=\"glass_of_water\">),
      form_remote_tag(:update => { :success => 'glass_of_beer', :failure => "glass_of_water" }, :url => { :action => :fast  })
  end

  test "form_remote_tag with method" do
    assert_dom_equal %(<form action=\"/fast\" method=\"post\" data-remote=\"true\" data-update-success=\"glass_of_beer\"><div style='margin:0;padding:0;display:inline'><input name='_method' type='hidden' value='put' /></div>),
      form_remote_tag(:update => "glass_of_beer", :url => { :action => :fast  }, :html => { :method => :put })
  end

  test "form_remote_tag with url" do
    form_remote_tag(:url => '/posts' ){}
    expected =  "<form action='/posts' method='post' data-remote='true'></form>"
    assert_dom_equal expected, output_buffer
  end

  test "form_remote_tag with block in erb" do
    __in_erb_template = ''
    form_remote_tag(:update => "glass_of_beer", :url => { :action => :fast  }) { concat "Hello world!" }
    assert_dom_equal %(<form action=\"/fast\" method=\"post\" data-remote=\"true\" data-update-success=\"glass_of_beer\">Hello world!</form>), output_buffer
  end

  test "remote_form_for with record identification with new record" do
    remote_form_for(@record, {:html => { :id => 'create-author' }}) {}
    expected = %(<form action='#{authors_path}' data-remote=\"true\" class='new_author' id='create-author' method='post'></form>)
    assert_dom_equal expected, output_buffer
  end

  test "remote_form_for with url" do
    remote_form_for(@record, {:html => { :id => 'create-author' }}) {} 
    expected = "<form action='/authors' data-remote='true' class='new_author' id='create-author' method='post'></form>"
    assert_dom_equal expected, output_buffer
  end

  test "remote_form_for with record identification without html options" do
    remote_form_for(@record) {}
    expected = %(<form action='#{authors_path}' data-remote=\"true\" class='new_author' method='post' id='new_author'></form>)
    assert_dom_equal expected, output_buffer
  end

  test "remote_form_for with record identification with existing record" do
    @record.save
    remote_form_for(@record) {}

    expected = %(<form action='#{author_path(@record)}' id='edit_author_1' method='post' data-remote=\"true\" class='edit_author'><div style='margin:0;padding:0;display:inline'><input name='_method' type='hidden' value='put' /></div></form>)
    assert_dom_equal expected, output_buffer
  end

  test "remote_form_for with new nested object and an excisting parent" do
    @author.save
    remote_form_for([@author, @article]) {}

    expected = %(<form action='#{author_articles_path(@author)}' data-remote=\"true\" class='new_article' method='post' id='new_article'></form>)
    assert_dom_equal expected, output_buffer
  end

  test "remote_form_for with existing object in list" do
    @author.save
    @article.save

    remote_form_for([@author, @article]) {}

    expected = %(<form action='#{author_article_path(@author, @article)}' id='edit_article_#{@article.id}' method='post' data-remote=\"true\" class='edit_article'><div style='margin:0;padding:0;display:inline'><input name='_method' type='hidden' value='put' /></div></form>)
    assert_dom_equal expected, output_buffer
  end

  test "on callbacks" do
    callbacks = [:uninitialized, :loading, :loaded, :interactive, :complete, :success, :failure]
    callbacks.each do |callback|
      assert_dom_equal %(<form action=\"/fast\" method=\"post\" data-remote=\"true\" data-update-success=\"glass_of_beer\" data-on#{callback}=\"monkeys();\">),
        form_remote_tag(:update => "glass_of_beer", :url => { :action => :fast  }, callback=>"monkeys();")
      assert_dom_equal %(<form action=\"/fast\" method=\"post\" data-remote=\"true\" data-update-success=\"glass_of_beer\" data-on#{callback}=\"monkeys();\">),
        form_remote_tag(:update => { :success => "glass_of_beer" }, :url => { :action => :fast  }, callback=>"monkeys();")
      assert_dom_equal %(<form action=\"/fast\" method=\"post\" data-remote=\"true\" data-update-failure=\"glass_of_beer\" data-on#{callback}=\"monkeys();\">),
        form_remote_tag(:update => { :failure => "glass_of_beer" }, :url => { :action => :fast  }, callback=>"monkeys();")
      assert_dom_equal %(<form action=\"/fast\" method=\"post\" data-remote=\"true\" data-update-failure=\"glass_of_water\" data-update-success=\"glass_of_beer\" data-on#{callback}=\"monkeys();\">),
        form_remote_tag(:update => { :success => "glass_of_beer", :failure => "glass_of_water" }, :url => { :action => :fast  }, callback=>"monkeys();")
    end

    #HTTP status codes 200 up to 599 have callbacks
    #these should work
    100.upto(599) do |callback|
      assert_dom_equal %(<form action=\"/fast\" method=\"post\" data-remote=\"true\" data-update-success=\"glass_of_beer\" data-on#{callback}=\"monkeys();\">),
        form_remote_tag(:update => "glass_of_beer", :url => { :action => :fast  }, callback=>"monkeys();")
    end

    #test 200 and 404
    assert_dom_equal %(<form action=\"/fast\" method=\"post\" data-remote=\"true\" data-update-success=\"glass_of_beer\" data-on200=\"monkeys();\" data-on404=\"bananas();\">),
      form_remote_tag(:update => "glass_of_beer", :url => { :action => :fast  }, 200=>"monkeys();", 404=>"bananas();")

    #these shouldn't
    1.upto(99) do |callback|
      assert_dom_equal %(<form action=\"/fast\" method=\"post\" data-remote=\"true\" data-update-success=\"glass_of_beer\" data-on#{callback}=\"monkeys();\">),
        form_remote_tag(:update => "glass_of_beer", :url => { :action => :fast  }, callback=>"monkeys();")
    end
    600.upto(999) do |callback|
      assert_dom_equal %(<form action=\"/fast\" method=\"post\" data-remote=\"true\" data-update-success=\"glass_of_beer\" data-on#{callback}=\"monkeys();\">),
        form_remote_tag(:update => "glass_of_beer", :url => { :action => :fast  }, callback=>"monkeys();")
    end

    #test ultimate combo
    assert_dom_equal %(<form data-on404=\"bananas();\" method=\"post\" data-onsuccess=\"s()\" action=\"/fast\" data-oncomplete=\"c();\" data-update-success=\"glass_of_beer\" data-on200=\"monkeys();\" data-onloading=\"c1()\" data-remote=\"true\" data-onfailure=\"f();\">),
      form_remote_tag(:update => "glass_of_beer", :url => { :action => :fast  }, :loading => "c1()", :success => "s()", :failure => "f();", :complete => "c();", 200=>"monkeys();", 404=>"bananas();")

  end

  test "submit_to_remote" do
    assert_dom_equal %(<input name=\"More beer!\" type=\"button\" value=\"1000000\" data-url=\"/empty_bottle\" data-remote-submit=\"true\" data-update-success=\"empty_bottle\" />),
      submit_to_remote("More beer!", 1_000_000, :url => { :action => 'empty_bottle' }, :update => "empty_bottle")
  end

  test "submit_to_remote simple" do
    expected = "<input name='create_btn' type='button' value='Create' data-remote-submit='true' data-url='/create' />"
    actual   = submit_to_remote 'create_btn', 'Create', :url => { :action => 'create' }
    assert_dom_equal expected, actual
  end

  test "submit_to_remote with success and failure" do
    expected = "<input name='update_btn' data-url='/update' data-remote-submit='true' data-update-failure='fail' data-update-success='succeed' value='Update' type='button' />"
    actual   = submit_to_remote 'update_btn', 'Update', :url => { :action => 'update' }, :update => { :success => "succeed", :failure => "fail" }
    assert_dom_equal expected, actual
  end

  test "observe_field" do
    assert_dom_equal %(<script type=\"text/javascript\" data-observe=\"true\" data-observed=\"glass\" data-frequency=\"300\" type=\"application/json\" data-url=\"/reorder_if_empty\"></script>),
      observe_field("glass", :frequency => 5.minutes, :url => { :action => "reorder_if_empty" })
  end

  test "observe_field with url, frequency, update and with" do
    actual = observe_field :suggest, :url => { :action => :find_suggestion }, :frequency => 0.25, :update => :suggest, :with => 'q'
    expected = "<script type='text/javascript' data-observe='true' data-observed='suggest' data-frequency='0.25' type='application/json' data-url='/find_suggestion' data-update-success='suggest' data-with='q'></script>"
    assert_dom_equal actual, expected
  end

  test "observe_field default frequency" do
    actual = observe_field :suggest
    expected = "<script type='text/javascript' data-observe='true' data-observed='suggest' data-frequency='10' type='application/json'></script>"
    assert_dom_equal actual, expected
  end

  test "observe_field using with option" do
    expected = %(<script type=\"text/javascript\" data-observe=\"true\" data-observed=\"glass\" data-frequency=\"300\" type=\"application/json\" data-url=\"/check_value\" data-with=\"id=123\"></script>)
    assert_dom_equal expected, observe_field("glass", :frequency => 5.minutes, :url => { :action => "check_value" }, :with => 'id=123')
  end

  test "observe_field using condition option" do
    expected = %(<script type=\"text/javascript\" data-observe=\"true\" data-observed=\"glass\" data-frequency=\"300\" type=\"application/json\" data-url=\"/check_value\" data-condition=\"$('foo').val() == true\"></script>)
    assert_dom_equal expected, observe_field("glass", :frequency => 5.minutes, :url => { :action => "check_value" }, :condition => '$(\'foo\').val() == true')
  end

  test "observe_field using json in with option" do
    expected = %(<script data-with=\"{'id':value}\" data-observed=\"glass\" data-url=\"/check_value\" data-observe=\"true\" type=\"application/json\" data-frequency=\"300\"></script>)
    assert_dom_equal expected, observe_field("glass", :frequency => 5.minutes, :url => { :action => "check_value" }, :with => "{'id':value}")
  end

  test "observe_field using function for callback" do
    assert_dom_equal %(<script data-observed=\"glass\" data-observe=\"true\" type=\"application/json\" data-onobserve=\"alert('Element changed')\" data-frequency=\"300\"></script>),
      observe_field("glass", :frequency => 5.minutes, :function => "alert('Element changed')")
  end

  test "observe_form" do
    assert_dom_equal %(<script data-observed=\"cart\" data-url=\"/cart_changed\" data-observe=\"true\" type=\"application/json\" data-frequency=\"2\"></script>),
      observe_form("cart", :frequency => 2, :url => { :action => "cart_changed" })
  end

  test "observe_form using function for callback" do
    assert_dom_equal %(<script data-observed=\"cart\" data-observe=\"true\" type=\"application/json\" data-onobserve=\"alert('Form changed')\" data-frequency=\"2\"></script>),
      observe_form("cart", :frequency => 2, :function => "alert('Form changed')")
  end

  test "observe_field without frequency" do
    assert_dom_equal %(<script data-observed=\"glass\" data-observe=\"true\" type=\"application/json\" data-frequency='10'></script>),
      observe_field("glass")
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
