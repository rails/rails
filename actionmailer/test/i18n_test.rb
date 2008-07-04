require 'abstract_unit'

class I18nMailer < ActionMailer::Base
  def use_locale_charset(recipient)
    recipients recipient
    subject    "using locale charset"
    from       "tester@example.com"
    body       "x"
  end
  
  def use_explicit_charset(recipient)
    recipients recipient
    subject    "using explicit charset"
    from       "tester@example.com"
    body       "x"
    charset    "iso-8859-2"
  end
  
  def multiparted(recipient)
    recipients recipient
    subject    "Multiparted"
    from       "tester@example.com"
    body       "x"

    part "text/html" do |p|
      p.body = "<b>multiparted iso-8859-1 html</b>"
    end
    
    part :content_type => "text/plain",
      :body => "multiparted utf-8 text",
      :charset => 'utf-8'
  end
  
  def rxml_template(recipient)
    recipients recipient
    subject    "rendering rxml template"
    from       "tester@example.com"
  end
  
  def initialize_defaults(method_name)
    super
    mailer_name "test_mailer"
  end
end

I18n.backend.store_translations :'en-GB', { }
I18n.backend.store_translations :'de-DE', {
  :charset => 'iso-8859-1'
}

class I18nTest < Test::Unit::TestCase
  def setup
    @charset   = 'utf-8'
    @recipient = 'test@localhost'
  end
  
  def test_should_use_locale_charset
    assert_equal @charset, mail.charset
  end
  
  def test_should_use_default_charset_if_no_current_locale
    uses_locale nil do
      assert_equal @charset, mail.charset
    end
  end
  
  def test_mail_headers_should_contains_current_charset
    uses_locale 'de-DE' do
      assert_match /iso-8859-1/, mail.header['content-type'].body
    end
  end
  
  def test_should_use_charset_from_current_locale
    uses_locale 'de-DE' do
      assert_equal 'iso-8859-1', mail.charset
    end
  end
  
  def test_should_raise_exception_if_current_locale_doesnt_specify_a_charset
    assert_raise I18n::MissingTranslationData do
      uses_locale 'en-GB' do
        mail
      end
    end
  end
  
  def test_should_use_explicit_charset
    assert_equal 'iso-8859-2', mail('use_explicit_charset').charset
  end
  
  def test_mail_parts_charsets
    uses_locale 'de-DE' do
      charsets = mail('multiparted').parts.map(&:charset)
      assert_equal 'iso-8859-1', charsets[0]
      assert_equal 'iso-8859-1', charsets[1]
      assert_equal 'utf-8', charsets[2]
    end
  end
  
  def test_mail_parts_headers
    uses_locale 'de-DE' do
      content_types = mail('multiparted').parts.map(&:header).map do |header|
        header['content-type'].body
      end
      assert_match /iso-8859-1/, content_types[0]
      assert_match /iso-8859-1/, content_types[1]
      assert_match /utf-8/, content_types[2]
    end
  end
  
  # TODO: this case depends on XML Builder,
  # should we pass Builder::XmlMarkup.new :encoding => charset_from_i18n ?
  def _ignore_test_rxml_template_should_use_current_charset
    uses_locale 'de-DE' do
      assert_equal "<?xml version=\"1.0\" encoding=\"iso-8859-1\"?>\n<test/>",
        mail('rxml_template').body.strip
    end
  end
  
  private
    def mail(method = 'use_locale_charset')
      I18nMailer.__send__('create_' + method, @recipient)
    end
    
    def uses_locale(locale, &block)
      begin
        I18n.locale = locale
        yield
      ensure
        I18n.locale = I18n.default_locale
      end
    end
end
