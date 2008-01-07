require 'abstract_unit'

class SanitizerTest < Test::Unit::TestCase
  def setup
    @sanitizer = nil # used by assert_sanitizer
  end

  def test_strip_tags
    sanitizer = HTML::FullSanitizer.new
    assert_equal("<<<bad html", sanitizer.sanitize("<<<bad html"))
    assert_equal("<<", sanitizer.sanitize("<<<bad html>"))
    assert_equal("Dont touch me", sanitizer.sanitize("Dont touch me"))
    assert_equal("This is a test.", sanitizer.sanitize("<p>This <u>is<u> a <a href='test.html'><strong>test</strong></a>.</p>"))
    assert_equal("Weirdos", sanitizer.sanitize("Wei<<a>a onclick='alert(document.cookie);'</a>/>rdos"))
    assert_equal("This is a test.", sanitizer.sanitize("This is a test."))
    assert_equal(
    %{This is a test.\n\n\nIt no longer contains any HTML.\n}, sanitizer.sanitize(
    %{<title>This is <b>a <a href="" target="_blank">test</a></b>.</title>\n\n<!-- it has a comment -->\n\n<p>It no <b>longer <strong>contains <em>any <strike>HTML</strike></em>.</strong></b></p>\n}))
    assert_equal "This has a  here.", sanitizer.sanitize("This has a <!-- comment --> here.")
    [nil, '', '   '].each { |blank| assert_equal blank, sanitizer.sanitize(blank) }
  end

  def test_strip_links
    sanitizer = HTML::LinkSanitizer.new
    assert_equal "Dont touch me", sanitizer.sanitize("Dont touch me")    
    assert_equal "on my mind\nall day long", sanitizer.sanitize("<a href='almost'>on my mind</a>\n<A href='almost'>all day long</A>")
    assert_equal "0wn3d", sanitizer.sanitize("<a href='http://www.rubyonrails.com/'><a href='http://www.rubyonrails.com/' onlclick='steal()'>0wn3d</a></a>") 
    assert_equal "Magic", sanitizer.sanitize("<a href='http://www.rubyonrails.com/'>Mag<a href='http://www.ruby-lang.org/'>ic") 
    assert_equal "FrrFox", sanitizer.sanitize("<href onlclick='steal()'>FrrFox</a></href>") 
    assert_equal "My mind\nall <b>day</b> long", sanitizer.sanitize("<a href='almost'>My mind</a>\n<A href='almost'>all <b>day</b> long</A>")
    assert_equal "all <b>day</b> long", sanitizer.sanitize("<<a>a href='hello'>all <b>day</b> long<</A>/a>")

    assert_equal "<a<a", sanitizer.sanitize("<a<a")
  end

  def test_sanitize_form
    assert_sanitized "<form action=\"/foo/bar\" method=\"post\"><input></form>", ''
  end

  def test_sanitize_plaintext
    raw = "<plaintext><span>foo</span></plaintext>"
    assert_sanitized raw, "<span>foo</span>"
  end

  def test_sanitize_script
    assert_sanitized "a b c<script language=\"Javascript\">blah blah blah</script>d e f", "a b cd e f"
  end

  # fucked
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

  HTML::WhiteListSanitizer.allowed_tags.each do |tag_name|
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
    sanitizer = HTML::WhiteListSanitizer.new
    assert_equal(text, sanitizer.sanitize(text, :tags => %w(u)))
  end

  def test_should_allow_only_custom_tags
    text = "<u>foo</u> with <i>bar</i>"
    sanitizer = HTML::WhiteListSanitizer.new
    assert_equal("<u>foo</u> with bar", sanitizer.sanitize(text, :tags => %w(u)))
  end

  def test_should_allow_custom_tags_with_attributes
    text = %(<blockquote cite="http://example.com/">foo</blockquote>)
    sanitizer = HTML::WhiteListSanitizer.new
    assert_equal(text, sanitizer.sanitize(text))
  end

  def test_should_allow_custom_tags_with_custom_attributes
    text = %(<blockquote foo="bar">Lorem ipsum</blockquote>)
    sanitizer = HTML::WhiteListSanitizer.new
    assert_equal(text, sanitizer.sanitize(text, :attributes => ['foo']))
  end

  [%w(img src), %w(a href)].each do |(tag, attr)|
    define_method "test_should_strip_#{attr}_attribute_in_#{tag}_with_bad_protocols" do
      assert_sanitized %(<#{tag} #{attr}="javascript:bang" title="1">boo</#{tag}>), %(<#{tag} title="1">boo</#{tag}>)
    end
  end

  def test_should_flag_bad_protocols
    sanitizer = HTML::WhiteListSanitizer.new
    %w(about chrome data disk hcp help javascript livescript lynxcgi lynxexec ms-help ms-its mhtml mocha opera res resource shell vbscript view-source vnd.ms.radio wysiwyg).each do |proto|
      assert sanitizer.send(:contains_bad_protocols?, 'src', "#{proto}://bad")
    end
  end

  def test_should_accept_good_protocols
    sanitizer = HTML::WhiteListSanitizer.new
    HTML::WhiteListSanitizer.allowed_protocols.each do |proto|
      assert !sanitizer.send(:contains_bad_protocols?, 'src', "#{proto}://good")
    end
  end

  def test_should_reject_hex_codes_in_protocol
    assert_sanitized %(<a href="&#37;6A&#37;61&#37;76&#37;61&#37;73&#37;63&#37;72&#37;69&#37;70&#37;74&#37;3A&#37;61&#37;6C&#37;65&#37;72&#37;74&#37;28&#37;22&#37;58&#37;53&#37;53&#37;22&#37;29">1</a>), "<a>1</a>"
    assert @sanitizer.send(:contains_bad_protocols?, 'src', "%6A%61%76%61%73%63%72%69%70%74%3A%61%6C%65%72%74%28%22%58%53%53%22%29")
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

  # fucked
  def test_should_sanitize_attributes
    assert_sanitized %(<SPAN title="'><script>alert()</script>">blah</SPAN>), %(<span title="'&gt;&lt;script&gt;alert()&lt;/script&gt;">blah</span>)
  end

  def test_should_sanitize_illegal_style_properties
    raw      = %(display:block; position:absolute; left:0; top:0; width:100%; height:100%; z-index:1; background-color:black; background-image:url(http://www.ragingplatypus.com/i/cam-full.jpg); background-x:center; background-y:center; background-repeat:repeat;)
    expected = %(display: block; width: 100%; height: 100%; background-color: black; background-image: ; background-x: center; background-y: center;)
    assert_equal expected, sanitize_css(raw)
  end

  def test_should_sanitize_with_trailing_space
    raw = "display:block; "
    expected = "display: block;"
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

  def test_should_sanitize_img_vbscript
    assert_sanitized %(<img src='vbscript:msgbox("XSS")' />), '<img />'
  end

protected
  def assert_sanitized(input, expected = nil)
    @sanitizer ||= HTML::WhiteListSanitizer.new
    if input
      assert_dom_equal expected || input, @sanitizer.sanitize(input)
    else
      assert_nil @sanitizer.sanitize(input)
    end
  end

  def sanitize_css(input)
    (@sanitizer ||= HTML::WhiteListSanitizer.new).sanitize_css(input)
  end
end
