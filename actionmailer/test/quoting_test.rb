# encoding: utf-8
require 'abstract_unit'
require 'tempfile'

class QuotingTest < Test::Unit::TestCase
  # Move some tests from TMAIL here
  def test_unquote_quoted_printable
    a ="=?ISO-8859-1?Q?[166417]_Bekr=E6ftelse_fra_Rejsefeber?="
    b = TMail::Unquoter.unquote_and_convert_to(a, 'utf-8')
    assert_equal "[166417] Bekr\303\246ftelse fra Rejsefeber", b
  end

  def test_unquote_base64
    a ="=?ISO-8859-1?B?WzE2NjQxN10gQmVrcuZmdGVsc2UgZnJhIFJlanNlZmViZXI=?="
    b = TMail::Unquoter.unquote_and_convert_to(a, 'utf-8')
    assert_equal "[166417] Bekr\303\246ftelse fra Rejsefeber", b
  end

  def test_unquote_without_charset
    a ="[166417]_Bekr=E6ftelse_fra_Rejsefeber"
    b = TMail::Unquoter.unquote_and_convert_to(a, 'utf-8')
    assert_equal "[166417]_Bekr=E6ftelse_fra_Rejsefeber", b
  end

  def test_unqoute_multiple
    a ="=?utf-8?q?Re=3A_=5B12=5D_=23137=3A_Inkonsistente_verwendung_von_=22Hin?==?utf-8?b?enVmw7xnZW4i?="
    b = TMail::Unquoter.unquote_and_convert_to(a, 'utf-8')
    assert_equal "Re: [12] #137: Inkonsistente verwendung von \"Hinzuf\303\274gen\"", b
  end

  def test_unqoute_in_the_middle
    a ="Re: Photos =?ISO-8859-1?Q?Brosch=FCre_Rand?="
    b = TMail::Unquoter.unquote_and_convert_to(a, 'utf-8')
    assert_equal "Re: Photos Brosch\303\274re Rand", b
  end

  def test_unqoute_iso
    a ="=?ISO-8859-1?Q?Brosch=FCre_Rand?="
    b = TMail::Unquoter.unquote_and_convert_to(a, 'iso-8859-1')
    expected = "Brosch\374re Rand"
    expected.force_encoding 'iso-8859-1' if expected.respond_to?(:force_encoding)
    assert_equal expected, b
  end

  def test_quote_multibyte_chars
    original = "\303\246 \303\270 and \303\245"
    original.force_encoding('ASCII-8BIT') if original.respond_to?(:force_encoding)

    result = execute_in_sandbox(<<-CODE)
      $:.unshift(File.dirname(__FILE__) + "/../lib/")
      if RUBY_VERSION < '1.9'
        $KCODE = 'u'
        require 'jcode'
      end
      require 'action_mailer/quoting'
      include ActionMailer::Quoting
      quoted_printable(#{original.inspect}, "UTF-8")
    CODE

    unquoted = TMail::Unquoter.unquote_and_convert_to(result, nil)
    assert_equal unquoted, original
  end


  # test an email that has been created using \r\n newlines, instead of
  # \n newlines.
  def test_email_quoted_with_0d0a
    mail = TMail::Mail.parse(IO.read("#{File.dirname(__FILE__)}/fixtures/raw_email_quoted_with_0d0a"))
    assert_match %r{Elapsed time}, mail.body
  end

  def test_email_with_partially_quoted_subject
    mail = TMail::Mail.parse(IO.read("#{File.dirname(__FILE__)}/fixtures/raw_email_with_partially_quoted_subject"))
    assert_equal "Re: Test: \"\346\274\242\345\255\227\" mid \"\346\274\242\345\255\227\" tail", mail.subject
  end

  private
    # This whole thing *could* be much simpler, but I don't think Tempfile,
    # popen and others exist on all platforms (like Windows).
    def execute_in_sandbox(code)
      test_name = "#{File.dirname(__FILE__)}/am-quoting-test.#{$$}.rb"
      res_name = "#{File.dirname(__FILE__)}/am-quoting-test.#{$$}.out"

      File.open(test_name, "w+") do |file|
        file.write(<<-CODE)
          block = Proc.new do
            #{code}
          end
          puts block.call
        CODE
      end

      system("ruby #{test_name} > #{res_name}") or raise "could not run test in sandbox"
      File.read(res_name).chomp
    ensure
      File.delete(test_name) rescue nil
      File.delete(res_name) rescue nil
    end
end
