require "#{File.dirname(__FILE__)}/../abstract_unit"
require "#{File.dirname(__FILE__)}/../testing_sandbox"

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

  def test_truncate_multibyte
    with_kcode 'none' do
      assert_equal "\354\225\210\353\205\225\355...", truncate("\354\225\210\353\205\225\355\225\230\354\204\270\354\232\224", 10) 
    end
    with_kcode 'u' do
      assert_equal "\354\225\204\353\246\254\353\236\221 \354\225\204\353\246\254 ...",
        truncate("\354\225\204\353\246\254\353\236\221 \354\225\204\353\246\254 \354\225\204\353\235\274\353\246\254\354\230\244", 10)
    end
  end
  
  def test_strip_links
    assert_equal "Dont touch me", strip_links("Dont touch me")
    assert_equal "<a<a", strip_links("<a<a")
    assert_equal "on my mind\nall day long", strip_links("<a href='almost'>on my mind</a>\n<A href='almost'>all day long</A>")
    assert_equal "0wn3d", strip_links("<a href='http://www.rubyonrails.com/'><a href='http://www.rubyonrails.com/' onlclick='steal()'>0wn3d</a></a>") 
    assert_equal "Magic", strip_links("<a href='http://www.rubyonrails.com/'>Mag<a href='http://www.ruby-lang.org/'>ic") 
    assert_equal "FrrFox", strip_links("<href onlclick='steal()'>FrrFox</a></href>") 
    assert_equal "My mind\nall <b>day</b> long", strip_links("<a href='almost'>My mind</a>\n<A href='almost'>all <b>day</b> long</A>")
    assert_equal "all <b>day</b> long", strip_links("<<a>a href='hello'>all <b>day</b> long<</A>/a>")
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

  def test_excerpt_with_utf8
    with_kcode('u') do
      assert_equal("...ﬃciency could not be h...", excerpt("That's why eﬃciency could not be helped", 'could', 8))
    end
    with_kcode('none') do
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

  def test_sanitize_form
    assert_sanitized "<form action=\"/foo/bar\" method=\"post\"><input></form>", ''
  end

  def test_sanitize_plaintext
    raw = "<plaintext><span>foo</span></plaintext>"
    assert_sanitized raw, "<span>foo</span>"
  end

  def test_sanitize_script
    raw = "a b c<script language=\"Javascript\">blah blah blah</script>d e f"
    assert_sanitized raw, "a b cd e f"
  end

  def test_sanitize_js_handlers
    raw = %{onthis="do that" <a href="#" onclick="hello" name="foo" onbogus="remove me">hello</a>}
    assert_sanitized raw, %{onthis="do that" <a name="foo" href="#">hello</a>}
  end

  def test_sanitize_javascript_href
    raw = %{href="javascript:bang" <a href="javascript:bang" name="hello">foo</a>, <span href="javascript:bang">bar</span>}
    assert_sanitized raw, %{href="javascript:bang" <a name="hello">foo</a>, <span>bar</span>}
  end
  
  def test_sanitize_image_src
    raw = %{src="javascript:bang" <img src="javascript:bang" width="5">foo</img>, <span src="javascript:bang">bar</span>}
    assert_sanitized raw, %{src="javascript:bang" <img width="5">foo</img>, <span>bar</span>}
  end

  ActionView::Helpers::TextHelper.sanitized_allowed_tags.each do |tag_name|
    define_method "test_should_allow_#{tag_name}_tag" do
      assert_sanitized "start <#{tag_name} title=\"1\" onclick=\"foo\">foo <bad>bar</bad> baz</#{tag_name}> end", %(start <#{tag_name} title="1">foo bar baz</#{tag_name}> end)
    end
  end

  def test_should_allow_anchors
    assert_sanitized %(<a href="foo" onclick="bar"><script>baz</script></a>), %(<a href="foo"></a>)
  end

  # RFC 3986, sec 4.2
  def test_allow_colons_in_path_component
    assert_sanitized("<a href=\"./this:that\">foo</a>")
  end

  %w(src width height alt).each do |img_attr|
    define_method "test_should_allow_image_#{img_attr}_attribute" do
      assert_sanitized %(<img #{img_attr}="foo" onclick="bar" />), %(<img #{img_attr}="foo" />)
    end
  end

  def test_should_handle_non_html
    assert_sanitized 'abc'
  end

  def test_should_handle_blank_text
    assert_sanitized nil
    assert_sanitized ''
  end

  def test_should_allow_custom_tags
    text = "<u>foo</u>"
    assert_equal(text, sanitize(text, :tags => %w(u)))
  end

  def test_should_allow_custom_tags_with_attributes
    text = %(<fieldset foo="bar">foo</fieldset>)
    assert_equal(text, sanitize(text, :attributes => ['foo']))
  end

  [%w(img src), %w(a href)].each do |(tag, attr)|
    define_method "test_should_strip_#{attr}_attribute_in_#{tag}_with_bad_protocols" do
      assert_sanitized %(<#{tag} #{attr}="javascript:bang" title="1">boo</#{tag}>), %(<#{tag} title="1">boo</#{tag}>)
    end
  end

  def test_should_flag_bad_protocols
    %w(about chrome data disk hcp help javascript livescript lynxcgi lynxexec ms-help ms-its mhtml mocha opera res resource shell vbscript view-source vnd.ms.radio wysiwyg).each do |proto|
      assert contains_bad_protocols?('src', "#{proto}://bad")
    end
  end

  def test_should_accept_good_protocols
    sanitized_allowed_protocols.each do |proto|
      assert !contains_bad_protocols?('src', "#{proto}://good")
    end
  end

  def test_should_reject_hex_codes_in_protocol
    assert contains_bad_protocols?('src', "%6A%61%76%61%73%63%72%69%70%74%3A%61%6C%65%72%74%28%22%58%53%53%22%29")
    assert_sanitized %(<a href="&#37;6A&#37;61&#37;76&#37;61&#37;73&#37;63&#37;72&#37;69&#37;70&#37;74&#37;3A&#37;61&#37;6C&#37;65&#37;72&#37;74&#37;28&#37;22&#37;58&#37;53&#37;53&#37;22&#37;29">1</a>), "<a>1</a>"
  end

  def test_should_block_script_tag
    assert_sanitized %(<SCRIPT\nSRC=http://ha.ckers.org/xss.js></SCRIPT>), ""
  end

  [%(<IMG SRC="javascript:alert('XSS');">), 
   %(<IMG SRC=javascript:alert('XSS')>), 
   %(<IMG SRC=JaVaScRiPt:alert('XSS')>), 
   %(<IMG """><SCRIPT>alert("XSS")</SCRIPT>">),
   %(<IMG SRC=javascript:alert(&quot;XSS&quot;)>),
   %(<IMG SRC=javascript:alert(String.fromCharCode(88,83,83))>),
   %(<IMG SRC=&#106;&#97;&#118;&#97;&#115;&#99;&#114;&#105;&#112;&#116;&#58;&#97;&#108;&#101;&#114;&#116;&#40;&#39;&#88;&#83;&#83;&#39;&#41;>),
   %(<IMG SRC=&#0000106&#0000097&#0000118&#0000097&#0000115&#0000099&#0000114&#0000105&#0000112&#0000116&#0000058&#0000097&#0000108&#0000101&#0000114&#0000116&#0000040&#0000039&#0000088&#0000083&#0000083&#0000039&#0000041>),
   %(<IMG SRC=&#x6A&#x61&#x76&#x61&#x73&#x63&#x72&#x69&#x70&#x74&#x3A&#x61&#x6C&#x65&#x72&#x74&#x28&#x27&#x58&#x53&#x53&#x27&#x29>),
   %(<IMG SRC="jav\tascript:alert('XSS');">),
   %(<IMG SRC="jav&#x09;ascript:alert('XSS');">),
   %(<IMG SRC="jav&#x0A;ascript:alert('XSS');">),
   %(<IMG SRC="jav&#x0D;ascript:alert('XSS');">),
   %(<IMG SRC=" &#14;  javascript:alert('XSS');">),
   %(<IMG SRC=`javascript:alert("RSnake says, 'XSS'")`>)].each_with_index do |img_hack, i|
    define_method "test_should_not_fall_for_xss_image_hack_#{i+1}" do
      assert_sanitized img_hack, "<img>"
    end
  end
  
  def test_should_sanitize_tag_broken_up_by_null
    assert_sanitized %(<SCR\0IPT>alert(\"XSS\")</SCR\0IPT>), "alert(\"XSS\")"
  end
  
  def test_should_sanitize_invalid_script_tag
    assert_sanitized %(<SCRIPT/XSS SRC="http://ha.ckers.org/xss.js"></SCRIPT>), ""
  end
  
  def test_should_sanitize_script_tag_with_multiple_open_brackets
    assert_sanitized %(<<SCRIPT>alert("XSS");//<</SCRIPT>), "&lt;"
    assert_sanitized %(<iframe src=http://ha.ckers.org/scriptlet.html\n<a), %(&lt;a)
  end
  
  def test_should_sanitize_unclosed_script
    assert_sanitized %(<SCRIPT SRC=http://ha.ckers.org/xss.js?<B>), "<b>"
  end
  
  def test_should_sanitize_half_open_scripts
    assert_sanitized %(<IMG SRC="javascript:alert('XSS')"), "<img>"
  end
  
  def test_should_not_fall_for_ridiculous_hack
    img_hack = %(<IMG\nSRC\n=\n"\nj\na\nv\na\ns\nc\nr\ni\np\nt\n:\na\nl\ne\nr\nt\n(\n'\nX\nS\nS\n'\n)\n"\n>)
    assert_sanitized img_hack, "<img>"
  end

  def test_should_sanitize_attributes
    assert_sanitized %(<SPAN title="'><script>alert()</script>">blah</SPAN>), %(<span title="'&gt;&lt;script&gt;alert()&lt;/script&gt;">blah</span>)
  end

  def test_should_sanitize_illegal_style_properties
    raw      = %(display:block; position:absolute; left:0; top:0; width:100%; height:100%; z-index:1; background-color:black; background-image:url(http://www.ragingplatypus.com/i/cam-full.jpg); background-x:center; background-y:center; background-repeat:repeat;)
    expected = %(display: block; width: 100%; height: 100%; background-color: black; background-image: ; background-x: center; background-y: center;)
    assert_equal expected, sanitize_css(raw)
  end

  def test_should_sanitize_xul_style_attributes
    raw = %(-moz-binding:url('http://ha.ckers.org/xssmoz.xml#xss'))
    assert_equal '', sanitize_css(raw)
  end
  
  def test_should_sanitize_invalid_tag_names
    assert_sanitized(%(a b c<script/XSS src="http://ha.ckers.org/xss.js"></script>d e f), "a b cd e f")
  end
  
  def test_should_sanitize_non_alpha_and_non_digit_characters_in_tags
    assert_sanitized('<a onclick!#$%&()*~+-_.,:;?@[/|\]^`=alert("XSS")>foo</a>', "<a>foo</a>")
  end
  
  def test_should_sanitize_invalid_tag_names_in_single_tags
    assert_sanitized('<img/src="http://ha.ckers.org/xss.js"/>', "<img />")
  end

  def test_should_sanitize_img_dynsrc_lowsrc
    assert_sanitized(%(<img lowsrc="javascript:alert('XSS')" />), "<img />")
  end

  def test_should_sanitize_div_background_image_unicode_encoded
    raw = %(background-image:\0075\0072\006C\0028'\006a\0061\0076\0061\0073\0063\0072\0069\0070\0074\003a\0061\006c\0065\0072\0074\0028.1027\0058.1053\0053\0027\0029'\0029)
    assert_equal '', sanitize_css(raw)
  end

  def test_should_sanitize_div_style_expression
    raw = %(width: expression(alert('XSS'));)
    assert_equal '', sanitize_css(raw)
  end
  
  def test_should_sanitize_style_attribute
    raw = %(<div style="display:block; background:url(http://rubyonrails.com); background-image: url(rubyonrails)">foo</div>)
    assert_equal %(<div style="display: block; background: ; background-image: ;">foo</div>), sanitize(raw, :attributes => 'style')
  end

  def test_should_sanitize_img_vbscript
     assert_sanitized %(<img src='vbscript:msgbox("XSS")' />), '<img />'
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

  def test_strip_tags
    assert_equal("<<<bad html", strip_tags("<<<bad html"))
    assert_equal("<<", strip_tags("<<<bad html>"))
    assert_equal("Dont touch me", strip_tags("Dont touch me"))
    assert_equal("This is a test.", strip_tags("<p>This <u>is<u> a <a href='test.html'><strong>test</strong></a>.</p>"))
    assert_equal("Weirdos", strip_tags("Wei<<a>a onclick='alert(document.cookie);'</a>/>rdos"))
    assert_equal("This is a test.", strip_tags("This is a test."))
    assert_equal(
    %{This is a test.\n\n\nIt no longer contains any HTML.\n}, strip_tags(
    %{<title>This is <b>a <a href="" target="_blank">test</a></b>.</title>\n\n<!-- it has a comment -->\n\n<p>It no <b>longer <strong>contains <em>any <strike>HTML</strike></em>.</strong></b></p>\n}))
    assert_equal "This has a  here.", strip_tags("This has a <!-- comment --> here.")
    [nil, '', '   '].each { |blank| assert_equal blank, strip_tags(blank) }
  end

  def assert_sanitized(text, expected = nil)
    assert_equal((expected || text), sanitize(text))
  end
end
