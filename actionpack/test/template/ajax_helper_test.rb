require 'abstract_unit'
require 'active_model'

class Author
  extend ActiveModel::Naming
  include ActiveModel::Conversion

  attr_reader :id
  def save; @id = 1 end
  def new_record?; @id.nil? end
  def name
    @id.nil? ? 'new author' : "author ##{@id}"
  end
end

class Article
  extend ActiveModel::Naming
  include ActiveModel::Conversion
  attr_reader :id
  attr_reader :author_id
  def save; @id = 1; @author_id = 1 end
  def new_record?; @id.nil? end
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
        if options.is_a?(String)
          options
        else
          url =  "http://www.example.com/"
          url << options[:action].to_s if options and options[:action]
          url << "?a=#{options[:a]}" if options && options[:a]
          url << "&b=#{options[:b]}" if options && options[:a] && options[:b]
          url
        end
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
    assert_dom_equal %(<a class=\"fine\" href=\"#\" data-remote=\"true\" data-url=\"http://www.example.com/whatnot\">Remote outauthor</a>),
      link_to_remote("Remote outauthor", { :url => { :action => "whatnot" }}, { :class => "fine"  })
    assert_dom_equal %(<a href=\"#\" data-remote=\"true\" data-url=\"http://www.example.com/whatnot\" data-oncomplete=\"alert(request.responseText)\">Remote outauthor</a>),
      link_to_remote("Remote outauthor", :complete => "alert(request.responseText)", :url => { :action => "whatnot"  })
    assert_dom_equal %(<a href=\"#\" data-remote=\"true\" data-url=\"http://www.example.com/whatnot\" data-onsuccess=\"alert(request.responseText)\">Remote outauthor</a>),
      link_to_remote("Remote outauthor", :success => "alert(request.responseText)", :url => { :action => "whatnot"  })
    assert_dom_equal %(<a href=\"#\" data-remote=\"true\" data-url=\"http://www.example.com/whatnot\" data-onfailure=\"alert(request.responseText)\">Remote outauthor</a>),
      link_to_remote("Remote outauthor", :failure => "alert(request.responseText)", :url => { :action => "whatnot"  })
    assert_dom_equal %(<a href=\"#\" data-remote=\"true\" data-url=\"http://www.example.com/whatnot?a=10&amp;b=20\" data-onfailure=\"alert(request.responseText)\">Remote outauthor</a>),
      link_to_remote("Remote outauthor", :failure => "alert(request.responseText)", :url => { :action => "whatnot", :a => '10', :b => '20' })
    assert_dom_equal %(<a href=\"#\" data-remote=\"true\" data-url=\"http://www.example.com/whatnot\" data-remote-type=\"synchronous\">Remote outauthor</a>),
      link_to_remote("Remote outauthor", :url => { :action => "whatnot" }, :type => :synchronous)
    assert_dom_equal %(<a href=\"#\" data-remote=\"true\" data-url=\"http://www.example.com/whatnot\" data-update-position=\"bottom\">Remote outauthor</a>),
      link_to_remote("Remote outauthor", :url => { :action => "whatnot" }, :position => :bottom)
  end

  test "link_to_remote with method delete" do
    assert_dom_equal %(<a class=\"fine\" href=\"#\" data-remote=\"true\" data-url=\"http://www.example.com/whatnot\" data-method=\"delete\" rel=\"nofollow\">Remote outauthor</a>),
      link_to_remote("Remote outauthor", { :url => { :action => "whatnot" }, :method => "delete"}, { :class => "fine"  })
  end

  test "link_to_remote html options" do
    assert_dom_equal %(<a class=\"fine\" href=\"#\" data-remote=\"true\" data-url=\"http://www.example.com/whatnot\">Remote outauthor</a>),
      link_to_remote("Remote outauthor", { :url => { :action => "whatnot"  }, :html => { :class => "fine" } })
  end

  test "link_to_remote url quote escaping" do
    assert_dom_equal %(<a href="#" data-remote=\"true\" data-url=\"http://www.example.com/whatnot\\\'s\">Remote</a>),
      link_to_remote("Remote", { :url => { :action => "whatnot's" } })
  end

  test "button_to_remote" do
    assert_dom_equal %(<input class=\"fine\" type=\"button\" value=\"Remote outpost\" data-remote=\"true\" data-url=\"http://www.example.com/whatnot\" />),
      button_to_remote("Remote outpost", { :url => { :action => "whatnot" }}, { :class => "fine"  })
    assert_dom_equal %(<input type=\"button\" value=\"Remote outpost\" data-remote=\"true\" data-url=\"http://www.example.com/whatnot\" data-oncomplete=\"alert(request.reponseText)\" />),
      button_to_remote("Remote outpost", :complete => "alert(request.reponseText)", :url => { :action => "whatnot"  })
    assert_dom_equal %(<input type=\"button\" value=\"Remote outpost\" data-remote=\"true\" data-url=\"http://www.example.com/whatnot\" data-onsuccess=\"alert(request.reponseText)\" />),
      button_to_remote("Remote outpost", :success => "alert(request.reponseText)", :url => { :action => "whatnot"  })
    assert_dom_equal %(<input type=\"button\" value=\"Remote outpost\" data-remote=\"true\" data-url=\"http://www.example.com/whatnot\" data-onfailure=\"alert(request.reponseText)\" />),
      button_to_remote("Remote outpost", :failure => "alert(request.reponseText)", :url => { :action => "whatnot"  })
    assert_dom_equal %(<input type=\"button\" value=\"Remote outpost\" data-remote=\"true\" data-url=\"http://www.example.com/whatnot?a=10&amp;b=20\" data-onfailure=\"alert(request.reponseText)\" />),
      button_to_remote("Remote outpost", :failure => "alert(request.reponseText)", :url => { :action => "whatnot", :a => '10', :b => '20' })
  end

  test "periodically_call_remote" do
    assert_dom_equal %(<script data-url=\"http://www.example.com/mehr_bier\" data-observe=\"true\" data-update-success=\"schremser_bier\" type=\"application/json\" data-periodical=\"true\"></script>),
      periodically_call_remote(:update => "schremser_bier", :url => { :action => "mehr_bier" })
  end

  test "periodically_call_remote_with_frequency" do
    assert_dom_equal(
      "<script data-periodical=\"true\" data-url=\"http://www.example.com/\" data-observe=\"true\" type=\"application/json\" data-frequency=\"2\"></script>",
      periodically_call_remote(:frequency => 2)
    )
  end

  test "form_remote_tag" do
    assert_dom_equal %(<form action=\"http://www.example.com/fast\" method=\"post\" data-remote=\"true\" data-update-success=\"glass_of_beer\">),
      form_remote_tag(:update => "glass_of_beer", :url => { :action => :fast  })
    assert_dom_equal %(<form action=\"http://www.example.com/fast\" method=\"post\" data-remote=\"true\" data-update-success=\"glass_of_beer\">),
      form_remote_tag(:update => { :success => "glass_of_beer" }, :url => { :action => :fast  })
    assert_dom_equal %(<form action=\"http://www.example.com/fast\" method=\"post\" data-remote=\"true\" data-update-failure=\"glass_of_water\">),
      form_remote_tag(:update => { :failure => "glass_of_water" }, :url => { :action => :fast  })
    assert_dom_equal %(<form action=\"http://www.example.com/fast\" method=\"post\" data-remote=\"true\" data-update-success=\"glass_of_beer\" data-update-failure=\"glass_of_water\">),
      form_remote_tag(:update => { :success => 'glass_of_beer', :failure => "glass_of_water" }, :url => { :action => :fast  })
  end

  test "form_remote_tag with method" do
    assert_dom_equal %(<form action=\"http://www.example.com/fast\" method=\"post\" data-remote=\"true\" data-update-success=\"glass_of_beer\"><div style='margin:0;padding:0;display:inline'><input name='_method' type='hidden' value='put' /></div>),
      form_remote_tag(:update => "glass_of_beer", :url => { :action => :fast  }, :html => { :method => :put })
  end

  test "form_remote_tag with block in erb" do
    __in_erb_template = ''
    form_remote_tag(:update => "glass_of_beer", :url => { :action => :fast  }) { concat "Hello world!" }
    assert_dom_equal %(<form action=\"http://www.example.com/fast\" method=\"post\" data-remote=\"true\" data-update-success=\"glass_of_beer\">Hello world!</form>), output_buffer
  end

  test "remote_form_for with record identification with new record" do
    remote_form_for(@record, {:html => { :id => 'create-author' }}) {}

    expected = %(<form action='#{authors_path}' data-remote=\"true\" class='new_author' id='create-author' method='post'></form>)
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

  test "remote_form_for with new object in list" do
    remote_form_for([@author, @article]) {}

    expected = %(<form action='#{author_articles_path(@author)}' data-remote=\"true\" class='new_article' method='post' id='new_article'></form>)
    assert_dom_equal expected, output_buffer
  end

  test "remote_form_for with existing object in list" do
    @author.save
    @article.save
    remote_form_for([@author, @article]) {}

    expected = %(<form action='#{author_article_path(@author, @article)}' id='edit_article_1' method='post' data-remote=\"true\" class='edit_article'><div style='margin:0;padding:0;display:inline'><input name='_method' type='hidden' value='put' /></div></form>)
    assert_dom_equal expected, output_buffer
  end

  test "on callbacks" do
    callbacks = [:uninitialized, :loading, :loaded, :interactive, :complete, :success, :failure]
    callbacks.each do |callback|
      assert_dom_equal %(<form action=\"http://www.example.com/fast\" method=\"post\" data-remote=\"true\" data-update-success=\"glass_of_beer\" data-on#{callback}=\"monkeys();\">),
        form_remote_tag(:update => "glass_of_beer", :url => { :action => :fast  }, callback=>"monkeys();")
      assert_dom_equal %(<form action=\"http://www.example.com/fast\" method=\"post\" data-remote=\"true\" data-update-success=\"glass_of_beer\" data-on#{callback}=\"monkeys();\">),
        form_remote_tag(:update => { :success => "glass_of_beer" }, :url => { :action => :fast  }, callback=>"monkeys();")
      assert_dom_equal %(<form action=\"http://www.example.com/fast\" method=\"post\" data-remote=\"true\" data-update-failure=\"glass_of_beer\" data-on#{callback}=\"monkeys();\">),
        form_remote_tag(:update => { :failure => "glass_of_beer" }, :url => { :action => :fast  }, callback=>"monkeys();")
      assert_dom_equal %(<form action=\"http://www.example.com/fast\" method=\"post\" data-remote=\"true\" data-update-failure=\"glass_of_water\" data-update-success=\"glass_of_beer\" data-on#{callback}=\"monkeys();\">),
        form_remote_tag(:update => { :success => "glass_of_beer", :failure => "glass_of_water" }, :url => { :action => :fast  }, callback=>"monkeys();")
    end

    #HTTP status codes 200 up to 599 have callbacks
    #these should work
    100.upto(599) do |callback|
      assert_dom_equal %(<form action=\"http://www.example.com/fast\" method=\"post\" data-remote=\"true\" data-update-success=\"glass_of_beer\" data-on#{callback}=\"monkeys();\">),
        form_remote_tag(:update => "glass_of_beer", :url => { :action => :fast  }, callback=>"monkeys();")
    end

    #test 200 and 404
    assert_dom_equal %(<form action=\"http://www.example.com/fast\" method=\"post\" data-remote=\"true\" data-update-success=\"glass_of_beer\" data-on200=\"monkeys();\" data-on404=\"bananas();\">),
      form_remote_tag(:update => "glass_of_beer", :url => { :action => :fast  }, 200=>"monkeys();", 404=>"bananas();")

    #these shouldn't
    1.upto(99) do |callback|
      assert_dom_equal %(<form action=\"http://www.example.com/fast\" method=\"post\" data-remote=\"true\" data-update-success=\"glass_of_beer\" data-on#{callback}=\"monkeys();\">),
        form_remote_tag(:update => "glass_of_beer", :url => { :action => :fast  }, callback=>"monkeys();")
    end
    600.upto(999) do |callback|
      assert_dom_equal %(<form action=\"http://www.example.com/fast\" method=\"post\" data-remote=\"true\" data-update-success=\"glass_of_beer\" data-on#{callback}=\"monkeys();\">),
        form_remote_tag(:update => "glass_of_beer", :url => { :action => :fast  }, callback=>"monkeys();")
    end

    #test ultimate combo
    assert_dom_equal %(<form data-on404=\"bananas();\" method=\"post\" data-onsuccess=\"s()\" action=\"http://www.example.com/fast\" data-oncomplete=\"c();\" data-update-success=\"glass_of_beer\" data-on200=\"monkeys();\" data-onloading=\"c1()\" data-remote=\"true\" data-onfailure=\"f();\">),
      form_remote_tag(:update => "glass_of_beer", :url => { :action => :fast  }, :loading => "c1()", :success => "s()", :failure => "f();", :complete => "c();", 200=>"monkeys();", 404=>"bananas();")

  end

  test "submit_to_remote" do
    assert_dom_equal %(<input name=\"More beer!\" type=\"button\" value=\"1000000\" data-url=\"http://www.example.com/\" data-submit=\"true\" data-update-success=\"empty_bottle\" />),
      submit_to_remote("More beer!", 1_000_000, :update => "empty_bottle")
  end

  test "observe_field" do
    assert_dom_equal %(<script type=\"text/javascript\" data-observe=\"true\" data-observed=\"glass\" data-frequency=\"300\" type=\"application/json\" data-url=\"http://www.example.com/reorder_if_empty\"></script>),
      observe_field("glass", :frequency => 5.minutes, :url => { :action => "reorder_if_empty" })
  end

  test "observe_field using with option" do
    expected = %(<script type=\"text/javascript\" data-observe=\"true\" data-observed=\"glass\" data-frequency=\"300\" type=\"application/json\" data-url=\"http://www.example.com/check_value\" data-with=\"'id=' + encodeURIComponent(value)\"></script>)
    assert_dom_equal expected, observe_field("glass", :frequency => 5.minutes, :url => { :action => "check_value" }, :with => 'id')
    assert_dom_equal expected, observe_field("glass", :frequency => 5.minutes, :url => { :action => "check_value" }, :with => "'id=' + encodeURIComponent(value)")
  end

  test "observe_field using json in with option" do
    expected = %(<script data-with=\"{'id':value}\" data-observed=\"glass\" data-url=\"http://www.example.com/check_value\" data-observe=\"true\" type=\"application/json\" data-frequency=\"300\"></script>)
    assert_dom_equal expected, observe_field("glass", :frequency => 5.minutes, :url => { :action => "check_value" }, :with => "{'id':value}")
  end

  test "observe_field using function for callback" do
    assert_dom_equal %(<script data-observed=\"glass\" data-url=\"http://www.example.com/\" data-onobserve=\"function(element, value) {alert('Element changed')}\" data-observe=\"true\" type=\"application/json\" data-frequency=\"300\"></script>),
      observe_field("glass", :frequency => 5.minutes, :function => "alert('Element changed')")
  end

  test "observe_form" do
    assert_dom_equal %(<script data-observed=\"cart\" data-url=\"http://www.example.com/cart_changed\" data-observe=\"true\" type=\"application/json\" data-frequency=\"2\"></script>),
      observe_form("cart", :frequency => 2, :url => { :action => "cart_changed" })
  end

  test "observe_form using function for callback" do
    assert_dom_equal %(<script data-observed=\"cart\" data-url=\"http://www.example.com/\" data-onobserve=\"function(element, value) {alert('Form changed')}\" data-observe=\"true\" type=\"application/json\" data-frequency=\"2\"></script>),
      observe_form("cart", :frequency => 2, :function => "alert('Form changed')")
  end

  test "observe_field without frequency" do
    assert_dom_equal %(<script data-observed=\"glass\" data-url=\"http://www.example.com/\" data-observe=\"true\" type=\"application/json\"></script>),
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
