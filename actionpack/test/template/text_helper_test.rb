# encoding: us-ascii
require 'abstract_unit'
require 'testing_sandbox'

class TextHelperTest < ActionView::TestCase
  tests ActionView::Helpers::TextHelper
  include TestingSandbox

  def setup
    super
    # This simulates the fact that instance variables are reset every time
    # a view is rendered.  The cycle helper depends on this behavior.
    @_cycles = nil if (defined? @_cycles)
  end

  def test_concat
    self.output_buffer = 'foo'
    assert_equal 'foobar', concat('bar')
    assert_equal 'foobar', output_buffer
  end

  def test_simple_format_should_be_html_safe
    assert simple_format("<b> test with html tags </b>").html_safe?
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

     assert_equal %q(<p class="test">This is a classy test</p>), simple_format("This is a classy test", :class => 'test')
     assert_equal %Q(<p class="test">para 1</p>\n\n<p class="test">para 2</p>), simple_format("para 1\n\npara 2", :class => 'test')
  end

  def test_simple_format_should_sanitize_input_when_sanitize_option_is_not_false
    assert_equal "<p><b> test with unsafe string </b></p>", simple_format("<b> test with unsafe string </b><script>code!</script>")
  end

  def test_simple_format_should_not_sanitize_input_when_sanitize_option_is_false
    assert_equal "<p><b> test with unsafe string </b><script>code!</script></p>", simple_format("<b> test with unsafe string </b><script>code!</script>", {}, :sanitize => false)
  end

  def test_simple_format_should_not_be_html_safe_when_sanitize_option_is_false
    assert !simple_format("<b> test with unsafe string </b><script>code!</script>", {}, :sanitize => false).html_safe?
  end

  def test_truncate_should_not_be_html_safe
    assert !truncate("Hello World!", :length => 12).html_safe?
  end

  def test_truncate
    assert_equal "Hello World!", truncate("Hello World!", :length => 12)
    assert_equal "Hello Wor...", truncate("Hello World!!", :length => 12)
  end

  def test_truncate_should_not_escape_input
    assert_equal "Hello <sc...", truncate("Hello <script>code!</script>World!!", :length => 12)
  end

  def test_truncate_should_use_default_length_of_30
    str = "This is a string that will go longer then the default truncate length of 30"
    assert_equal str[0...27] + "...", truncate(str)
  end

  def test_truncate_with_options_hash
    assert_equal "This is a string that wil[...]", truncate("This is a string that will go longer then the default truncate length of 30", :omission => "[...]")
    assert_equal "Hello W...", truncate("Hello World!", :length => 10)
    assert_equal "Hello[...]", truncate("Hello World!", :omission => "[...]", :length => 10)
    assert_equal "Hello[...]", truncate("Hello Big World!", :omission => "[...]", :length => 13, :separator => ' ')
    assert_equal "Hello Big[...]", truncate("Hello Big World!", :omission => "[...]", :length => 14, :separator => ' ')
    assert_equal "Hello Big[...]", truncate("Hello Big World!", :omission => "[...]", :length => 15, :separator => ' ')
  end

  if RUBY_VERSION < '1.9.0'
    def test_truncate_multibyte
      with_kcode 'none' do
        assert_equal "\354\225\210\353\205\225\355...", truncate("\354\225\210\353\205\225\355\225\230\354\204\270\354\232\224", :length => 10)
      end
      with_kcode 'u' do
        assert_equal "\354\225\204\353\246\254\353\236\221 \354\225\204\353\246\254 ...",
          truncate("\354\225\204\353\246\254\353\236\221 \354\225\204\353\246\254 \354\225\204\353\235\274\353\246\254\354\230\244", :length => 10)
      end
    end
  else
    def test_truncate_multibyte
      # .mb_chars always returns a UTF-8 String.
      # assert_equal "\354\225\210\353\205\225\355...",
      #   truncate("\354\225\210\353\205\225\355\225\230\354\204\270\354\232\224", :length => 10)

      assert_equal "\354\225\204\353\246\254\353\236\221 \354\225\204\353\246\254 ...".force_encoding('UTF-8'),
        truncate("\354\225\204\353\246\254\353\236\221 \354\225\204\353\246\254 \354\225\204\353\235\274\353\246\254\354\230\244".force_encoding('UTF-8'), :length => 10)
    end
  end

  def test_highlight_should_be_html_safe
    assert highlight("This is a beautiful morning", "beautiful").html_safe?
  end

  def test_highlight
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

  def test_highlight_should_sanitize_input
    assert_equal(
      "This is a <strong class=\"highlight\">beautiful</strong> morning",
      highlight("This is a beautiful morning<script>code!</script>", "beautiful")
    )
  end

  def test_highlight_should_not_sanitize_if_sanitize_option_if_false
    assert_equal(
      "This is a <strong class=\"highlight\">beautiful</strong> morning<script>code!</script>",
      highlight("This is a beautiful morning<script>code!</script>", "beautiful", :sanitize => false)
    )
  end

  def test_highlight_with_regexp
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

  def test_highlight_with_multiple_phrases_in_one_pass
    assert_equal %(<em>wow</em> <em>em</em>), highlight('wow em', %w(wow em), '<em>\1</em>')
  end

  def test_highlight_with_options_hash
    assert_equal(
      "This is a <b>beautiful</b> morning, but also a <b>beautiful</b> day",
      highlight("This is a beautiful morning, but also a beautiful day", "beautiful", :highlighter => '<b>\1</b>')
    )
  end

  def test_highlight_on_an_html_safe_string
    assert_equal(
      "<p>This is a <b>beautiful</b> morning, but also a <b>beautiful</b> day</p>",
      highlight("<p>This is a beautiful morning, but also a beautiful day</p>".html_safe, "beautiful", :highlighter => '<b>\1</b>')
    )
  end

  def test_highlight_with_html
    assert_equal(
      "<p>This is a <strong class=\"highlight\">beautiful</strong> morning, but also a <strong class=\"highlight\">beautiful</strong> day</p>",
      highlight("<p>This is a beautiful morning, but also a beautiful day</p>", "beautiful")
    )
    assert_equal(
      "<p>This is a <em><strong class=\"highlight\">beautiful</strong></em> morning, but also a <strong class=\"highlight\">beautiful</strong> day</p>",
      highlight("<p>This is a <em>beautiful</em> morning, but also a beautiful day</p>", "beautiful")
    )
    assert_equal(
      "<p>This is a <em class=\"error\"><strong class=\"highlight\">beautiful</strong></em> morning, but also a <strong class=\"highlight\">beautiful</strong> <span class=\"last\">day</span></p>",
      highlight("<p>This is a <em class=\"error\">beautiful</em> morning, but also a beautiful <span class=\"last\">day</span></p>", "beautiful")
    )
    assert_equal(
      "<p class=\"beautiful\">This is a <strong class=\"highlight\">beautiful</strong> morning, but also a <strong class=\"highlight\">beautiful</strong> day</p>",
      highlight("<p class=\"beautiful\">This is a beautiful morning, but also a beautiful day</p>", "beautiful")
    )
    assert_equal(
      "<p>This is a <strong class=\"highlight\">beautiful</strong> <a href=\"http://example.com/beautiful#top?what=beautiful%20morning&amp;when=now+then\">morning</a>, but also a <strong class=\"highlight\">beautiful</strong> day</p>",
      highlight("<p>This is a beautiful <a href=\"http://example.com/beautiful\#top?what=beautiful%20morning&when=now+then\">morning</a>, but also a beautiful day</p>", "beautiful")
    )
  end

  def test_excerpt
    assert_equal("...is a beautiful morn...", excerpt("This is a beautiful morning", "beautiful", 5))
    assert_equal("This is a...", excerpt("This is a beautiful morning", "this", 5))
    assert_equal("...iful morning", excerpt("This is a beautiful morning", "morning", 5))
    assert_nil excerpt("This is a beautiful morning", "day")
  end

  def test_excerpt_should_not_be_html_safe
    assert !excerpt('This is a beautiful! morning', 'beautiful', 5).html_safe?
  end

  def test_excerpt_in_borderline_cases
    assert_equal("", excerpt("", "", 0))
    assert_equal("a", excerpt("a", "a", 0))
    assert_equal("...b...", excerpt("abc", "b", 0))
    assert_equal("abc", excerpt("abc", "b", 1))
    assert_equal("abc...", excerpt("abcd", "b", 1))
    assert_equal("...abc", excerpt("zabc", "b", 1))
    assert_equal("...abc...", excerpt("zabcd", "b", 1))
    assert_equal("zabcd", excerpt("zabcd", "b", 2))

    # excerpt strips the resulting string before ap-/prepending excerpt_string.
    # whether this behavior is meaningful when excerpt_string is not to be
    # appended is questionable.
    assert_equal("zabcd", excerpt("  zabcd  ", "b", 4))
    assert_equal("...abc...", excerpt("z  abc  d", "b", 1))
  end

  def test_excerpt_with_regex
    assert_equal('...is a beautiful! mor...', excerpt('This is a beautiful! morning', 'beautiful', 5))
    assert_equal('...is a beautiful? mor...', excerpt('This is a beautiful? morning', 'beautiful', 5))
  end

  def test_excerpt_with_options_hash
    assert_equal("...is a beautiful morn...", excerpt("This is a beautiful morning", "beautiful", :radius => 5))
    assert_equal("[...]is a beautiful morn[...]", excerpt("This is a beautiful morning", "beautiful", :omission => "[...]",:radius => 5))
    assert_equal(
      "This is the ultimate supercalifragilisticexpialidoceous very looooooooooooooooooong looooooooooooong beautiful morning with amazing sunshine and awesome tempera[...]",
      excerpt("This is the ultimate supercalifragilisticexpialidoceous very looooooooooooooooooong looooooooooooong beautiful morning with amazing sunshine and awesome temperatures. So what are you gonna do about it?", "very",
      :omission => "[...]")
    )
  end

  if RUBY_VERSION < '1.9'
    def test_excerpt_with_utf8
      with_kcode('u') do
        assert_equal("...\357\254\203ciency could not be...", excerpt("That's why e\357\254\203ciency could not be helped", 'could', 8))
      end
      with_kcode('none') do
        assert_equal("...\203ciency could not be...", excerpt("That's why e\357\254\203ciency could not be helped", 'could', 8))
      end
    end
  else
    def test_excerpt_with_utf8
      assert_equal("...\357\254\203ciency could not be...".force_encoding('UTF-8'), excerpt("That's why e\357\254\203ciency could not be helped".force_encoding('UTF-8'), 'could', 8))
      # .mb_chars always returns UTF-8, even in 1.9. This is not great, but it's how it works. Let's work this out.
      # assert_equal("...\203ciency could not be...", excerpt("That's why e\357\254\203ciency could not be helped".force_encoding("BINARY"), 'could', 8))
    end
  end

  def test_word_wrap
    assert_equal("my very very\nvery long\nstring", word_wrap("my very very very long string", 15))
  end

  def test_word_wrap_with_extra_newlines
    assert_equal("my very very\nvery long\nstring\n\nwith another\nline", word_wrap("my very very very long string\n\nwith another line", 15))
  end

  def test_word_wrap_with_options_hash
    assert_equal("my very very\nvery long\nstring", word_wrap("my very very very long string", :line_width => 15))
  end

  def test_pluralization
    assert_equal("1 count", pluralize(1, "count"))
    assert_equal("2 counts", pluralize(2, "count"))
    assert_equal("1 count", pluralize('1', "count"))
    assert_equal("2 counts", pluralize('2', "count"))
    assert_equal("1,066 counts", pluralize('1,066', "count"))
    assert_equal("1.25 counts", pluralize('1.25', "count"))
    assert_equal("1.0 count", pluralize('1.0', "count"))
    assert_equal("1.00 count", pluralize('1.00', "count"))
    assert_equal("2 counters", pluralize(2, "count", "counters"))
    assert_equal("0 counters", pluralize(nil, "count", "counters"))
    assert_equal("2 people", pluralize(2, "person"))
    assert_equal("10 buffaloes", pluralize(10, "buffalo"))
    assert_equal("1 berry", pluralize(1, "berry"))
    assert_equal("12 berries", pluralize(12, "berry"))
  end

  def test_auto_link_parsing
    urls = %w(
      http://www.rubyonrails.com
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
      http://en.wikipedia.org/wiki/Texas_hold
      https://www.google.com/doku.php?id=gps:resource:scs:start
      http://connect.oraclecorp.com/search?search[q]=green+france&search[type]=Group
      http://of.openfoundry.org/projects/492/download#4th.Release.3
      http://maps.google.co.uk/maps?f=q&q=the+london+eye&ie=UTF8&ll=51.503373,-0.11939&spn=0.007052,0.012767&z=16&iwloc=A
    )

    urls.each do |url|
      assert_equal generate_result(url), auto_link(url)
    end
  end

  def generate_result(link_text, href = nil)
    href = CGI::escapeHTML(href || link_text)
    text = CGI::escapeHTML(link_text)
    %{<a href="#{href}">#{text}</a>}
  end

  def test_auto_link_should_not_be_html_safe
    email_raw    = 'santiago@wyeworks.com'
    link_raw     = 'http://www.rubyonrails.org'

    assert !auto_link(nil).html_safe?, 'should not be html safe'
    assert !auto_link('').html_safe?, 'should not be html safe'
    assert !auto_link("#{link_raw} #{link_raw} #{link_raw}").html_safe?, 'should not be html safe'
    assert !auto_link("hello #{email_raw}").html_safe?, 'should not be html safe'
    assert !auto_link(link_raw.html_safe).html_safe?, 'should not be html safe'
    assert !auto_link(email_raw.html_safe).html_safe?, 'should not be html safe'
  end

  def test_auto_link_email_address
    email_raw    = 'aaron@tenderlovemaking.com'
    email_result = %{<a href="mailto:#{email_raw}">#{email_raw}</a>}
    assert !auto_link_email_addresses(email_result).html_safe?, 'should not be html safe'
  end

  def test_auto_link
    email_raw    = 'david@loudthinking.com'
    email_result = %{<a href="mailto:#{email_raw}">#{email_raw}</a>}
    link_raw     = 'http://www.rubyonrails.com'
    link_result  = generate_result(link_raw)
    link_result_with_options = %{<a href="#{link_raw}" target="_blank">#{link_raw}</a>}

    assert_equal '', auto_link(nil)
    assert_equal '', auto_link('')
    assert_equal "#{link_result} #{link_result} #{link_result}", auto_link("#{link_raw} #{link_raw} #{link_raw}")

    assert_equal %(hello #{email_result}), auto_link("hello #{email_raw}", :email_addresses)
    assert_equal %(Go to #{link_result}), auto_link("Go to #{link_raw}", :urls)
    assert_equal %(Go to #{link_raw}), auto_link("Go to #{link_raw}", :email_addresses)
    assert_equal %(Go to #{link_result} and say hello to #{email_result}), auto_link("Go to #{link_raw} and say hello to #{email_raw}")
    assert_equal %(<p>Link #{link_result}</p>), auto_link("<p>Link #{link_raw}</p>")
    assert_equal %(<p>#{link_result} Link</p>), auto_link("<p>#{link_raw} Link</p>")
    assert_equal %(<p>Link #{link_result_with_options}</p>), auto_link("<p>Link #{link_raw}</p>", :all, {:target => "_blank"})
    assert_equal %(Go to #{link_result}.), auto_link(%(Go to #{link_raw}.))
    assert_equal %(<p>Go to #{link_result}, then say hello to #{email_result}.</p>), auto_link(%(<p>Go to #{link_raw}, then say hello to #{email_raw}.</p>))
    assert_equal %(#{link_result} #{link_result}), auto_link(%(#{link_result} #{link_raw}))

    email2_raw    = '+david@loudthinking.com'
    email2_result = %{<a href="mailto:#{email2_raw}">#{email2_raw}</a>}
    assert_equal email2_result, auto_link(email2_raw)

    email3_raw    = '+david@loudthinking.com'
    email3_result = %{<a href="&#109;&#97;&#105;&#108;&#116;&#111;&#58;+%64%61%76%69%64@%6c%6f%75%64%74%68%69%6e%6b%69%6e%67.%63%6f%6d">#{email3_raw}</a>}
    assert_equal email3_result, auto_link(email3_raw, :all, :encode => :hex)
    assert_equal email3_result, auto_link(email3_raw, :email_addresses, :encode => :hex)

    link2_raw    = 'www.rubyonrails.com'
    link2_result = generate_result(link2_raw, "http://#{link2_raw}")
    assert_equal %(Go to #{link2_result}), auto_link("Go to #{link2_raw}", :urls)
    assert_equal %(Go to #{link2_raw}), auto_link("Go to #{link2_raw}", :email_addresses)
    assert_equal %(<p>Link #{link2_result}</p>), auto_link("<p>Link #{link2_raw}</p>")
    assert_equal %(<p>#{link2_result} Link</p>), auto_link("<p>#{link2_raw} Link</p>")
    assert_equal %(Go to #{link2_result}.), auto_link(%(Go to #{link2_raw}.))
    assert_equal %(<p>Say hello to #{email_result}, then go to #{link2_result}.</p>), auto_link(%(<p>Say hello to #{email_raw}, then go to #{link2_raw}.</p>))

    link3_raw    = 'http://manuals.ruby-on-rails.com/read/chapter.need_a-period/103#page281'
    link3_result = generate_result(link3_raw)
    assert_equal %(Go to #{link3_result}), auto_link("Go to #{link3_raw}", :urls)
    assert_equal %(Go to #{link3_raw}), auto_link("Go to #{link3_raw}", :email_addresses)
    assert_equal %(<p>Link #{link3_result}</p>), auto_link("<p>Link #{link3_raw}</p>")
    assert_equal %(<p>#{link3_result} Link</p>), auto_link("<p>#{link3_raw} Link</p>")
    assert_equal %(Go to #{link3_result}.), auto_link(%(Go to #{link3_raw}.))
    assert_equal %(<p>Go to #{link3_result}. Seriously, #{link3_result}? I think I'll say hello to #{email_result}. Instead.</p>),
       auto_link(%(<p>Go to #{link3_raw}. Seriously, #{link3_raw}? I think I'll say hello to #{email_raw}. Instead.</p>))

    link4_raw    = 'http://foo.example.com/controller/action?parm=value&p2=v2#anchor123'
    link4_result = generate_result(link4_raw)
    assert_equal %(<p>Link #{link4_result}</p>), auto_link("<p>Link #{link4_raw}</p>")
    assert_equal %(<p>#{link4_result} Link</p>), auto_link("<p>#{link4_raw} Link</p>")

    link5_raw    = 'http://foo.example.com:3000/controller/action'
    link5_result = generate_result(link5_raw)
    assert_equal %(<p>#{link5_result} Link</p>), auto_link("<p>#{link5_raw} Link</p>")

    link6_raw    = 'http://foo.example.com:3000/controller/action+pack'
    link6_result = generate_result(link6_raw)
    assert_equal %(<p>#{link6_result} Link</p>), auto_link("<p>#{link6_raw} Link</p>")

    link7_raw    = 'http://foo.example.com/controller/action?parm=value&p2=v2#anchor-123'
    link7_result = generate_result(link7_raw)
    assert_equal %(<p>#{link7_result} Link</p>), auto_link("<p>#{link7_raw} Link</p>")

    link8_raw    = 'http://foo.example.com:3000/controller/action.html'
    link8_result = generate_result(link8_raw)
    assert_equal %(Go to #{link8_result}), auto_link("Go to #{link8_raw}", :urls)
    assert_equal %(Go to #{link8_raw}), auto_link("Go to #{link8_raw}", :email_addresses)
    assert_equal %(<p>Link #{link8_result}</p>), auto_link("<p>Link #{link8_raw}</p>")
    assert_equal %(<p>#{link8_result} Link</p>), auto_link("<p>#{link8_raw} Link</p>")
    assert_equal %(Go to #{link8_result}.), auto_link(%(Go to #{link8_raw}.))
    assert_equal %(<p>Go to #{link8_result}. Seriously, #{link8_result}? I think I'll say hello to #{email_result}. Instead.</p>),
       auto_link(%(<p>Go to #{link8_raw}. Seriously, #{link8_raw}? I think I'll say hello to #{email_raw}. Instead.</p>))

    link9_raw    = 'http://business.timesonline.co.uk/article/0,,9065-2473189,00.html'
    link9_result = generate_result(link9_raw)
    assert_equal %(Go to #{link9_result}), auto_link("Go to #{link9_raw}", :urls)
    assert_equal %(Go to #{link9_raw}), auto_link("Go to #{link9_raw}", :email_addresses)
    assert_equal %(<p>Link #{link9_result}</p>), auto_link("<p>Link #{link9_raw}</p>")
    assert_equal %(<p>#{link9_result} Link</p>), auto_link("<p>#{link9_raw} Link</p>")
    assert_equal %(Go to #{link9_result}.), auto_link(%(Go to #{link9_raw}.))
    assert_equal %(<p>Go to #{link9_result}. Seriously, #{link9_result}? I think I'll say hello to #{email_result}. Instead.</p>),
       auto_link(%(<p>Go to #{link9_raw}. Seriously, #{link9_raw}? I think I'll say hello to #{email_raw}. Instead.</p>))

    link10_raw    = 'http://www.mail-archive.com/ruby-talk@ruby-lang.org/'
    link10_result = generate_result(link10_raw)
    assert_equal %(<p>#{link10_result} Link</p>), auto_link("<p>#{link10_raw} Link</p>")
  end

  def test_auto_link_should_sanitize_input_when_sanitize_option_is_not_false
    link_raw     = %{http://www.rubyonrails.com?id=1&num=2}
    assert_equal %{<a href="http://www.rubyonrails.com?id=1&amp;num=2">http://www.rubyonrails.com?id=1&amp;num=2</a>}, auto_link(link_raw)
  end

  def test_auto_link_should_not_sanitize_input_when_sanitize_option_is_false
    link_raw     = %{http://www.rubyonrails.com?id=1&num=2}
    assert_equal %{<a href="http://www.rubyonrails.com?id=1&num=2">http://www.rubyonrails.com?id=1&num=2</a>}, auto_link(link_raw, :sanitize => false)
  end

  def test_auto_link_other_protocols
    ftp_raw = 'ftp://example.com/file.txt'
    assert_equal %(Download #{generate_result(ftp_raw)}), auto_link("Download #{ftp_raw}")
  end

  def test_auto_link_already_linked
    linked1 = generate_result('Ruby On Rails', 'http://www.rubyonrails.com')
    linked2 = %('<a href="http://www.example.com">www.example.com</a>')
    linked3 = %('<a href="http://www.example.com" rel="nofollow">www.example.com</a>')
    linked4 = %('<a href="http://www.example.com"><b>www.example.com</b></a>')
    linked5 = %('<a href="#close">close</a> <a href="http://www.example.com"><b>www.example.com</b></a>')
    assert_equal linked1, auto_link(linked1)
    assert_equal linked2, auto_link(linked2)
    assert_equal linked3, auto_link(linked3)
    assert_equal linked4, auto_link(linked4)
    assert_equal linked5, auto_link(linked5)

    linked_email = %Q(<a href="mailto:david@loudthinking.com">Mail me</a>)
    assert_equal linked_email, auto_link(linked_email)
  end

  def test_auto_link_within_tags
    link_raw    = 'http://www.rubyonrails.org/images/rails.png'
    link_result = %Q(<img src="#{link_raw}" />)
    assert_equal link_result, auto_link(link_result)
  end

  def test_auto_link_with_brackets
    link1_raw = 'http://en.wikipedia.org/wiki/Sprite_(computer_graphics)'
    link1_result = generate_result(link1_raw)
    assert_equal link1_result, auto_link(link1_raw)
    assert_equal "(link: #{link1_result})", auto_link("(link: #{link1_raw})")

    link2_raw = 'http://en.wikipedia.org/wiki/Sprite_[computer_graphics]'
    link2_result = generate_result(link2_raw)
    assert_equal link2_result, auto_link(link2_raw)
    assert_equal "[link: #{link2_result}]", auto_link("[link: #{link2_raw}]")

    link3_raw = 'http://en.wikipedia.org/wiki/Sprite_{computer_graphics}'
    link3_result = generate_result(link3_raw)
    assert_equal link3_result, auto_link(link3_raw)
    assert_equal "{link: #{link3_result}}", auto_link("{link: #{link3_raw}}")
  end

  def test_auto_link_at_eol
    url1 = "http://api.rubyonrails.com/Foo.html"
    url2 = "http://www.ruby-doc.org/core/Bar.html"

    assert_equal %(<p><a href="#{url1}">#{url1}</a><br /><a href="#{url2}">#{url2}</a><br /></p>), auto_link("<p>#{url1}<br />#{url2}<br /></p>")
  end

  def test_auto_link_with_block
    url = "http://api.rubyonrails.com/Foo.html"
    email = "fantabulous@shiznadel.ic"

    assert_equal %(<p><a href="#{url}">#{url[0...7]}...</a><br /><a href="mailto:#{email}">#{email[0...7]}...</a><br /></p>), auto_link("<p>#{url}<br />#{email}<br /></p>") { |url| truncate(url, :length => 10) }
  end

  def test_auto_link_with_block_with_html
    pic = "http://example.com/pic.png"
    url = "http://example.com/album?a&b=c"

    assert_equal %(My pic: <a href="#{pic}"><img src="#{pic}" width="160px"></a> -- full album here #{generate_result(url)}), auto_link("My pic: #{pic} -- full album here #{url}") { |link|
      if link =~ /\.(jpg|gif|png|bmp|tif)$/i
        raw %(<img src="#{link}" width="160px">)
      else
        link
      end
    }
  end

  def test_auto_link_with_options_hash
    assert_dom_equal 'Welcome to my new blog at <a href="http://www.myblog.com/" class="menu" target="_blank">http://www.myblog.com/</a>. Please e-mail me at <a href="mailto:me@email.com" class="menu" target="_blank">me@email.com</a>.',
      auto_link("Welcome to my new blog at http://www.myblog.com/. Please e-mail me at me@email.com.",
                :link => :all, :html => { :class => "menu", :target => "_blank" })
  end

  def test_auto_link_with_multiple_trailing_punctuations
    url = "http://youtube.com"
    url_result = generate_result(url)
    assert_equal url_result, auto_link(url)
    assert_equal "(link: #{url_result}).", auto_link("(link: #{url}).")
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

  def test_current_cycle_with_default_name
    cycle("even","odd")
    assert_equal "even", current_cycle
    cycle("even","odd")
    assert_equal "odd", current_cycle
    cycle("even","odd")
    assert_equal "even", current_cycle
  end

  def test_current_cycle_with_named_cycles
    cycle("red", "blue", :name => "colors")
    assert_equal "red", current_cycle("colors")
    cycle("red", "blue", :name => "colors")
    assert_equal "blue", current_cycle("colors")
    cycle("red", "blue", :name => "colors")
    assert_equal "red", current_cycle("colors")
  end

  def test_current_cycle_safe_call
    assert_nothing_raised { current_cycle }
    assert_nothing_raised { current_cycle("colors") }
  end

  def test_current_cycle_with_more_than_two_names
    cycle(1,2,3)
    assert_equal "1", current_cycle
    cycle(1,2,3)
    assert_equal "2", current_cycle
    cycle(1,2,3)
    assert_equal "3", current_cycle
    cycle(1,2,3)
    assert_equal "1", current_cycle
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
