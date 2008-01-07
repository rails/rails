require 'abstract_unit'
require 'testing_sandbox'

class TextHelperTest < Test::Unit::TestCase
  include ActionView::Helpers::TextHelper
  include ActionView::Helpers::TagHelper
  include TestingSandbox

  def setup
    # This simulates the fact that instance variables are reset every time
    # a view is rendered.  The cycle helper depends on this behavior.
    @_cycles = nil if (defined? @_cycles)
  end

  def test_simple_format
    assert_equal "<p></p>", simple_format(nil)

    assert_equal "<p>crazy\n<br /> cross\n<br /> platform linebreaks</p>", simple_format("crazy\r\n cross\r platform linebreaks")
    assert_equal "<p>A paragraph</p>\n\n<p>and another one!</p>", simple_format("A paragraph\n\nand another one!")
    assert_equal "<p>A paragraph\n<br /> With a newline</p>", simple_format("A paragraph\n With a newline")

    text = "A\nB\nC\nD".freeze
    assert_equal "<p>A\n<br />B\n<br />C\n<br />D</p>", simple_format(text)

    text = "A\r\n  \nB\n\n\r\n\t\nC\nD".freeze
    assert_equal "<p>A\n<br />  \n<br />B</p>\n\n<p>\t\n<br />C\n<br />D</p>", simple_format(text)
  end

  def test_truncate
    assert_equal "Hello World!", truncate("Hello World!", 12)
    assert_equal "Hello Wor...", truncate("Hello World!!", 12)
  end

  def test_truncate_should_use_default_length_of_30
    str = "This is a string that will go longer then the default truncate length of 30"
    assert_equal str[0...27] + "...", truncate(str)
  end

  if RUBY_VERSION < '1.9.0'
    def test_truncate_multibyte
      with_kcode 'none' do
        assert_equal "\354\225\210\353\205\225\355...", truncate("\354\225\210\353\205\225\355\225\230\354\204\270\354\232\224", 10) 
      end
      with_kcode 'u' do
        assert_equal "\354\225\204\353\246\254\353\236\221 \354\225\204\353\246\254 ...",
          truncate("\354\225\204\353\246\254\353\236\221 \354\225\204\353\246\254 \354\225\204\353\235\274\353\246\254\354\230\244", 10)
      end
    end
  else
    def test_truncate_multibyte
      assert_equal "\354\225\210\353\205\225\355...",
        truncate("\354\225\210\353\205\225\355\225\230\354\204\270\354\232\224", 10)

      assert_equal "\354\225\204\353\246\254\353\236\221 \354\225\204\353\246\254 ...".force_encoding('UTF-8'),
        truncate("\354\225\204\353\246\254\353\236\221 \354\225\204\353\246\254 \354\225\204\353\235\274\353\246\254\354\230\244".force_encoding('UTF-8'), 10)
    end
  end

  def test_highlighter
    assert_equal(
      "This is a <strong class=\"highlight\">beautiful</strong> morning",
      highlight("This is a beautiful morning", "beautiful")
    )

    assert_equal(
      "This is a <strong class=\"highlight\">beautiful</strong> morning, but also a <strong class=\"highlight\">beautiful</strong> day",
      highlight("This is a beautiful morning, but also a beautiful day", "beautiful")
    )

    assert_equal(
      "This is a <b>beautiful</b> morning, but also a <b>beautiful</b> day",
      highlight("This is a beautiful morning, but also a beautiful day", "beautiful", '<b>\1</b>')
    )
    
    assert_equal(
      "This text is not changed because we supplied an empty phrase",
      highlight("This text is not changed because we supplied an empty phrase", nil)
    )

    assert_equal '   ', highlight('   ', 'blank text is returned verbatim')
  end

  def test_highlighter_with_regexp
    assert_equal(
      "This is a <strong class=\"highlight\">beautiful!</strong> morning",
      highlight("This is a beautiful! morning", "beautiful!")
    )

    assert_equal(
      "This is a <strong class=\"highlight\">beautiful! morning</strong>",
      highlight("This is a beautiful! morning", "beautiful! morning")
    )

    assert_equal(
      "This is a <strong class=\"highlight\">beautiful? morning</strong>",
      highlight("This is a beautiful? morning", "beautiful? morning")
    )
  end

  def test_highlighting_multiple_phrases_in_one_pass
    assert_equal %(<em>wow</em> <em>em</em>), highlight('wow em', %w(wow em), '<em>\1</em>')
  end

  def test_excerpt
    assert_equal("...is a beautiful morni...", excerpt("This is a beautiful morning", "beautiful", 5))
    assert_equal("This is a...", excerpt("This is a beautiful morning", "this", 5))
    assert_equal("...iful morning", excerpt("This is a beautiful morning", "morning", 5))
    assert_nil excerpt("This is a beautiful morning", "day")
  end

  def test_excerpt_with_regex
    assert_equal('...is a beautiful! morn...', excerpt('This is a beautiful! morning', 'beautiful', 5))
    assert_equal('...is a beautiful? morn...', excerpt('This is a beautiful? morning', 'beautiful', 5))
  end

  if RUBY_VERSION < '1.9'
    def test_excerpt_with_utf8
      with_kcode('u') do
        assert_equal("...ﬃciency could not be h...", excerpt("That's why eﬃciency could not be helped", 'could', 8))
      end
      with_kcode('none') do
        assert_equal("...\203ciency could not be h...", excerpt("That's why eﬃciency could not be helped", 'could', 8))
      end
    end
  else
    def test_excerpt_with_utf8
      assert_equal("...ﬃciency could not be h...".force_encoding('UTF-8'), excerpt("That's why eﬃciency could not be helped".force_encoding('UTF-8'), 'could', 8))
      assert_equal("...\203ciency could not be h...", excerpt("That's why eﬃciency could not be helped", 'could', 8))
    end
  end

  def test_word_wrap
    assert_equal("my very very\nvery long\nstring", word_wrap("my very very very long string", 15))
  end

  def test_word_wrap_with_extra_newlines
    assert_equal("my very very\nvery long\nstring\n\nwith another\nline", word_wrap("my very very very long string\n\nwith another line", 15))
  end

  def test_pluralization
    assert_equal("1 count", pluralize(1, "count"))
    assert_equal("2 counts", pluralize(2, "count"))
    assert_equal("1 count", pluralize('1', "count"))
    assert_equal("2 counts", pluralize('2', "count"))
    assert_equal("1,066 counts", pluralize('1,066', "count"))
    assert_equal("1.25 counts", pluralize('1.25', "count"))
    assert_equal("2 counters", pluralize(2, "count", "counters"))
    assert_equal("0 counters", pluralize(nil, "count", "counters"))
    assert_equal("2 people", pluralize(2, "person"))
    assert_equal("10 buffaloes", pluralize(10, "buffalo")) 
  end

  uses_mocha("should_just_add_s_for_pluralize_without_inflector_loaded") do
    def test_should_just_add_s_for_pluralize_without_inflector_loaded
      Object.expects(:const_defined?).with("Inflector").times(4).returns(false)
      assert_equal("1 count", pluralize(1, "count"))
      assert_equal("2 persons", pluralize(2, "person"))
      assert_equal("2 personss", pluralize("2", "persons"))
      assert_equal("2 counts", pluralize(2, "count"))
      assert_equal("10 buffalos", pluralize(10, "buffalo"))
    end
  end

  def test_auto_link_parsing
    urls = %w(http://www.rubyonrails.com
              http://www.rubyonrails.com:80
              http://www.rubyonrails.com/~minam
              https://www.rubyonrails.com/~minam
              http://www.rubyonrails.com/~minam/url%20with%20spaces
              http://www.rubyonrails.com/foo.cgi?something=here
              http://www.rubyonrails.com/foo.cgi?something=here&and=here
              http://www.rubyonrails.com/contact;new
              http://www.rubyonrails.com/contact;new%20with%20spaces
              http://www.rubyonrails.com/contact;new?with=query&string=params
              http://www.rubyonrails.com/~minam/contact;new?with=query&string=params
              http://en.wikipedia.org/wiki/Wikipedia:Today%27s_featured_picture_%28animation%29/January_20%2C_2007
              http://www.mail-archive.com/rails@lists.rubyonrails.org/
              http://www.amazon.com/Testing-Equal-Sign-In-Path/ref=pd_bbs_sr_1?ie=UTF8&s=books&qid=1198861734&sr=8-1
            )

    urls.each do |url|
      assert_equal %(<a href="#{url}">#{url}</a>), auto_link(url)
    end
  end

  def test_auto_linking
    email_raw    = 'david@loudthinking.com'
    email_result = %{<a href="mailto:#{email_raw}">#{email_raw}</a>}
    email2_raw    = '+david@loudthinking.com'
    email2_result = %{<a href="mailto:#{email2_raw}">#{email2_raw}</a>}
    link_raw     = 'http://www.rubyonrails.com'
    link_result  = %{<a href="#{link_raw}">#{link_raw}</a>}
    link_result_with_options  = %{<a href="#{link_raw}" target="_blank">#{link_raw}</a>}
    link2_raw    = 'www.rubyonrails.com'
    link2_result = %{<a href="http://#{link2_raw}">#{link2_raw}</a>}
    link3_raw    = 'http://manuals.ruby-on-rails.com/read/chapter.need_a-period/103#page281'
    link3_result = %{<a href="#{link3_raw}">#{link3_raw}</a>}
    link4_raw    = 'http://foo.example.com/controller/action?parm=value&p2=v2#anchor123'
    link4_result = %{<a href="#{link4_raw}">#{link4_raw}</a>}
    link5_raw    = 'http://foo.example.com:3000/controller/action'
    link5_result = %{<a href="#{link5_raw}">#{link5_raw}</a>}
    link6_raw    = 'http://foo.example.com:3000/controller/action+pack'
    link6_result = %{<a href="#{link6_raw}">#{link6_raw}</a>}
    link7_raw    = 'http://foo.example.com/controller/action?parm=value&p2=v2#anchor-123'
    link7_result = %{<a href="#{link7_raw}">#{link7_raw}</a>}
    link8_raw    = 'http://foo.example.com:3000/controller/action.html'
    link8_result = %{<a href="#{link8_raw}">#{link8_raw}</a>}
    link9_raw    = 'http://business.timesonline.co.uk/article/0,,9065-2473189,00.html'
    link9_result = %{<a href="#{link9_raw}">#{link9_raw}</a>}
    link10_raw    = 'http://www.mail-archive.com/ruby-talk@ruby-lang.org/'
    link10_result = %{<a href="#{link10_raw}">#{link10_raw}</a>}

    assert_equal %(hello #{email_result}), auto_link("hello #{email_raw}", :email_addresses)
    assert_equal %(Go to #{link_result}), auto_link("Go to #{link_raw}", :urls)
    assert_equal %(Go to #{link_raw}), auto_link("Go to #{link_raw}", :email_addresses)
    assert_equal %(Go to #{link_result} and say hello to #{email_result}), auto_link("Go to #{link_raw} and say hello to #{email_raw}")
    assert_equal %(<p>Link #{link_result}</p>), auto_link("<p>Link #{link_raw}</p>")
    assert_equal %(<p>#{link_result} Link</p>), auto_link("<p>#{link_raw} Link</p>")
    assert_equal %(<p>Link #{link_result_with_options}</p>), auto_link("<p>Link #{link_raw}</p>", :all, {:target => "_blank"})
    assert_equal %(Go to #{link_result}.), auto_link(%(Go to #{link_raw}.))
    assert_equal %(<p>Go to #{link_result}, then say hello to #{email_result}.</p>), auto_link(%(<p>Go to #{link_raw}, then say hello to #{email_raw}.</p>))
    assert_equal %(Go to #{link2_result}), auto_link("Go to #{link2_raw}", :urls)
    assert_equal %(Go to #{link2_raw}), auto_link("Go to #{link2_raw}", :email_addresses)
    assert_equal %(<p>Link #{link2_result}</p>), auto_link("<p>Link #{link2_raw}</p>")
    assert_equal %(<p>#{link2_result} Link</p>), auto_link("<p>#{link2_raw} Link</p>")
    assert_equal %(Go to #{link2_result}.), auto_link(%(Go to #{link2_raw}.))
    assert_equal %(<p>Say hello to #{email_result}, then go to #{link2_result}.</p>), auto_link(%(<p>Say hello to #{email_raw}, then go to #{link2_raw}.</p>))
    assert_equal %(Go to #{link3_result}), auto_link("Go to #{link3_raw}", :urls)
    assert_equal %(Go to #{link3_raw}), auto_link("Go to #{link3_raw}", :email_addresses)
    assert_equal %(<p>Link #{link3_result}</p>), auto_link("<p>Link #{link3_raw}</p>")
    assert_equal %(<p>#{link3_result} Link</p>), auto_link("<p>#{link3_raw} Link</p>")
    assert_equal %(Go to #{link3_result}.), auto_link(%(Go to #{link3_raw}.))
    assert_equal %(<p>Go to #{link3_result}. seriously, #{link3_result}? i think I'll say hello to #{email_result}. instead.</p>), auto_link(%(<p>Go to #{link3_raw}. seriously, #{link3_raw}? i think I'll say hello to #{email_raw}. instead.</p>))
    assert_equal %(<p>Link #{link4_result}</p>), auto_link("<p>Link #{link4_raw}</p>")
    assert_equal %(<p>#{link4_result} Link</p>), auto_link("<p>#{link4_raw} Link</p>")
    assert_equal %(<p>#{link5_result} Link</p>), auto_link("<p>#{link5_raw} Link</p>")
    assert_equal %(<p>#{link6_result} Link</p>), auto_link("<p>#{link6_raw} Link</p>")
    assert_equal %(<p>#{link7_result} Link</p>), auto_link("<p>#{link7_raw} Link</p>")
    assert_equal %(Go to #{link8_result}), auto_link("Go to #{link8_raw}", :urls)
    assert_equal %(Go to #{link8_raw}), auto_link("Go to #{link8_raw}", :email_addresses)
    assert_equal %(<p>Link #{link8_result}</p>), auto_link("<p>Link #{link8_raw}</p>")
    assert_equal %(<p>#{link8_result} Link</p>), auto_link("<p>#{link8_raw} Link</p>")
    assert_equal %(Go to #{link8_result}.), auto_link(%(Go to #{link8_raw}.))
    assert_equal %(<p>Go to #{link8_result}. seriously, #{link8_result}? i think I'll say hello to #{email_result}. instead.</p>), auto_link(%(<p>Go to #{link8_raw}. seriously, #{link8_raw}? i think I'll say hello to #{email_raw}. instead.</p>))
    assert_equal %(Go to #{link9_result}), auto_link("Go to #{link9_raw}", :urls)
    assert_equal %(Go to #{link9_raw}), auto_link("Go to #{link9_raw}", :email_addresses)
    assert_equal %(<p>Link #{link9_result}</p>), auto_link("<p>Link #{link9_raw}</p>")
    assert_equal %(<p>#{link9_result} Link</p>), auto_link("<p>#{link9_raw} Link</p>")
    assert_equal %(Go to #{link9_result}.), auto_link(%(Go to #{link9_raw}.))
    assert_equal %(<p>Go to #{link9_result}. seriously, #{link9_result}? i think I'll say hello to #{email_result}. instead.</p>), auto_link(%(<p>Go to #{link9_raw}. seriously, #{link9_raw}? i think I'll say hello to #{email_raw}. instead.</p>))
    assert_equal %(<p>#{link10_result} Link</p>), auto_link("<p>#{link10_raw} Link</p>")
    assert_equal email2_result, auto_link(email2_raw)
    assert_equal '', auto_link(nil)
    assert_equal '', auto_link('')
  end

  def test_auto_link_at_eol
    url1 = "http://api.rubyonrails.com/Foo.html"
    url2 = "http://www.ruby-doc.org/core/Bar.html"

    assert_equal %(<p><a href="#{url1}">#{url1}</a><br /><a href="#{url2}">#{url2}</a><br /></p>), auto_link("<p>#{url1}<br />#{url2}<br /></p>")
  end

  def test_auto_link_with_block
    url = "http://api.rubyonrails.com/Foo.html"
    email = "fantabulous@shiznadel.ic"

    assert_equal %(<p><a href="#{url}">#{url[0...7]}...</a><br /><a href="mailto:#{email}">#{email[0...7]}...</a><br /></p>), auto_link("<p>#{url}<br />#{email}<br /></p>") { |url| truncate(url, 10) }
  end

  def test_cycle_class
    value = Cycle.new("one", 2, "3")
    assert_equal("one", value.to_s)
    assert_equal("2", value.to_s)
    assert_equal("3", value.to_s)
    assert_equal("one", value.to_s)
    value.reset
    assert_equal("one", value.to_s)
    assert_equal("2", value.to_s)
    assert_equal("3", value.to_s)
  end
  
  def test_cycle_class_with_no_arguments
    assert_raise(ArgumentError) { value = Cycle.new() }
  end

  def test_cycle
    assert_equal("one", cycle("one", 2, "3"))
    assert_equal("2", cycle("one", 2, "3"))
    assert_equal("3", cycle("one", 2, "3"))
    assert_equal("one", cycle("one", 2, "3"))
    assert_equal("2", cycle("one", 2, "3"))
    assert_equal("3", cycle("one", 2, "3"))
  end
  
  def test_cycle_with_no_arguments
    assert_raise(ArgumentError) { value = cycle() }
  end
  
  def test_cycle_resets_with_new_values
    assert_equal("even", cycle("even", "odd"))
    assert_equal("odd", cycle("even", "odd"))
    assert_equal("even", cycle("even", "odd"))
    assert_equal("1", cycle(1, 2, 3))
    assert_equal("2", cycle(1, 2, 3))
    assert_equal("3", cycle(1, 2, 3))
    assert_equal("1", cycle(1, 2, 3))
  end
  
  def test_named_cycles
    assert_equal("1", cycle(1, 2, 3, :name => "numbers"))
    assert_equal("red", cycle("red", "blue", :name => "colors"))
    assert_equal("2", cycle(1, 2, 3, :name => "numbers"))
    assert_equal("blue", cycle("red", "blue", :name => "colors"))
    assert_equal("3", cycle(1, 2, 3, :name => "numbers"))
    assert_equal("red", cycle("red", "blue", :name => "colors"))
  end
  
  def test_default_named_cycle
    assert_equal("1", cycle(1, 2, 3))
    assert_equal("2", cycle(1, 2, 3, :name => "default"))
    assert_equal("3", cycle(1, 2, 3))
  end
  
  def test_reset_cycle
    assert_equal("1", cycle(1, 2, 3))
    assert_equal("2", cycle(1, 2, 3))
    reset_cycle
    assert_equal("1", cycle(1, 2, 3))
  end
  
  def test_reset_unknown_cycle
    reset_cycle("colors")
  end
  
  def test_recet_named_cycle
    assert_equal("1", cycle(1, 2, 3, :name => "numbers"))
    assert_equal("red", cycle("red", "blue", :name => "colors"))
    reset_cycle("numbers")
    assert_equal("1", cycle(1, 2, 3, :name => "numbers"))
    assert_equal("blue", cycle("red", "blue", :name => "colors"))
    assert_equal("2", cycle(1, 2, 3, :name => "numbers"))
    assert_equal("red", cycle("red", "blue", :name => "colors"))
  end
  
  def test_cycle_no_instance_variable_clashes
    @cycles = %w{Specialized Fuji Giant}
    assert_equal("red", cycle("red", "blue"))
    assert_equal("blue", cycle("red", "blue"))
    assert_equal("red", cycle("red", "blue"))
    assert_equal(%w{Specialized Fuji Giant}, @cycles)
  end
end
