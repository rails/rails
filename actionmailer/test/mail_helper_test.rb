require 'abstract_unit'

class HelperMailer < ActionMailer::Base
  def use_mail_helper
    @text = "But soft! What light through yonder window breaks? It is the east, " +
            "and Juliet is the sun. Arise, fair sun, and kill the envious moon, " +
            "which is sick and pale with grief that thou, her maid, art far more " +
            "fair than she. Be not her maid, for she is envious! Her vestal " +
            "livery is but sick and green, and none but fools do wear it. Cast " +
            "it off!"

    mail_with_defaults do |format|
      format.html { render(inline: "<%= block_format @text %>") }
    end
  end

  def use_format_paragraph
    @text = "But soft! What light through yonder window breaks?"

    mail_with_defaults do |format|
      format.html { render(inline: "<%= format_paragraph @text, 15, 1 %>") }
    end
  end

  def use_format_paragraph_with_long_first_word
    @text = "Antidisestablishmentarianism is very long."

    mail_with_defaults do |format|
      format.html { render(inline: "<%= format_paragraph @text, 10, 1 %>") }
    end
  end

  def use_mailer
    mail_with_defaults do |format|
      format.html { render(inline: "<%= mailer.message.subject %>") }
    end
  end

  def use_message
    mail_with_defaults do |format|
      format.html { render(inline: "<%= message.subject %>") }
    end
  end

  def use_block_format
    @text = <<-TEXT
This is the
first     paragraph.

The second
   paragraph.

* item1 * item2
  * item3
    TEXT

    mail_with_defaults do |format|
      format.html { render(inline: "<%= block_format @text %>") }
    end
  end

  protected

  def mail_with_defaults(&block)
    mail(to: "test@localhost", from: "tester@example.com",
          subject: "using helpers", &block)
  end
end

class MailerHelperTest < ActionMailer::TestCase
  def test_use_mail_helper
    mail = HelperMailer.use_mail_helper
    assert_match %r{  But soft!}, mail.body.encoded
    assert_match %r{east, and\r\n  Juliet}, mail.body.encoded
  end

  def test_use_mailer
    mail = HelperMailer.use_mailer
    assert_match "using helpers", mail.body.encoded
  end

  def test_use_message
    mail = HelperMailer.use_message
    assert_match "using helpers", mail.body.encoded
  end

  def test_use_format_paragraph
    mail = HelperMailer.use_format_paragraph
    assert_match " But soft! What\r\n light through\r\n yonder window\r\n breaks?", mail.body.encoded
  end

  def test_use_format_paragraph_with_long_first_word
    mail = HelperMailer.use_format_paragraph_with_long_first_word
    assert_equal " Antidisestablishmentarianism\r\n is very\r\n long.", mail.body.encoded
  end

  def test_use_block_format
    mail = HelperMailer.use_block_format
    expected = <<-TEXT
  This is the first paragraph.

  The second paragraph.

  * item1
  * item2
  * item3
    TEXT
    assert_equal expected.gsub("\n", "\r\n"), mail.body.encoded
  end
end

