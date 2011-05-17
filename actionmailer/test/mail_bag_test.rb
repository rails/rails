require 'abstract_unit'
require 'mailers/base_mailer'

class MailBagTest < ActiveSupport::TestCase
  test "sets mail subject" do
    mail_bag = BaseMailer.subject("Welcome!").welcome
    assert_equal "Welcome!", mail_bag.subject

    mail_bag = BaseMailer.welcome.subject("Welcome!")
    assert_equal "Welcome!", mail_bag.subject
  end

  test "sets mail to" do
    mail_bag = BaseMailer.to("konata@luckystar.net").welcome
    assert_equal ["konata@luckystar.net"], mail_bag.to

    mail_bag = BaseMailer.welcome.to("konata@luckystar.net")
    assert_equal ["konata@luckystar.net"], mail_bag.to
  end

  test "sets mail from" do
    mail_bag = BaseMailer.from("kagami@luckystar.net").welcome
    assert_equal ["kagami@luckystar.net"], mail_bag.from

    mail_bag = BaseMailer.welcome.from("kagami@luckystar.net")
    assert_equal ["kagami@luckystar.net"], mail_bag.from
  end

  test "sets mail cc" do
    mail_bag = BaseMailer.cc("tsukasa@luckystar.net").welcome
    assert_equal "tsukasa@luckystar.net", mail_bag.cc

    mail_bag = BaseMailer.welcome.cc("tsukasa@luckystar.net")
    assert_equal "tsukasa@luckystar.net", mail_bag.cc
  end

  test "sets mail bcc" do
    mail_bag = BaseMailer.bcc("iluvgirlsinglasses@luckystar.net").welcome
    assert_equal "iluvgirlsinglasses@luckystar.net", mail_bag.bcc

    mail_bag = BaseMailer.welcome.bcc("iluvgirlsinglasses@luckystar.net")
    assert_equal "iluvgirlsinglasses@luckystar.net", mail_bag.bcc
  end

  test "sets mail reply_to" do
    mail_bag = BaseMailer.reply_to("kagami@luckystar.net").welcome
    assert_equal "kagami@luckystar.net", mail_bag.reply_to

    mail_bag = BaseMailer.welcome.reply_to("kagami@luckystar.net")
    assert_equal "kagami@luckystar.net", mail_bag.reply_to
  end

  test "sets mail date" do
    date = Time.now

    mail_bag = BaseMailer.date(date).welcome
    assert_equal date, mail_bag.date

    mail_bag = BaseMailer.welcome.date(date)
    assert_equal date, mail_bag.date
  end

  test "sets mail header" do
    mail_bag = BaseMailer.headers("X-SPAM" => "Not SPAM").welcome
    assert_equal "Not SPAM", mail_bag.headers["X-SPAM"]

    mail_bag = BaseMailer.welcome.headers("X-SPAM" => "Not SPAM")
    assert_equal "Not SPAM", mail_bag.headers["X-SPAM"]
  end

  test "return list of mail objects" do
    mail_bag = BaseMailer.welcome.subject("Hello World!")
    assert_equal 1, mail_bag.mails.size
    assert_equal "Hello World!",  mail_bag.mails.first.subject
  end

  test "create multiple mails using to_bulk" do
    mail_bag = BaseMailer.welcome.to_bulk(["konata@luckystar.net", "miyuki@luckystar.net"])
    assert_equal 2, mail_bag.mails.size

    mail_bag = BaseMailer.welcome.to_bulk([["konata@luckystar.net","iluvgirlsinglasses@luckystar.net"], "miyuki@luckystar.net"])
    assert_equal 2, mail_bag.mails.size
  end

  test "retrives bulk recipients using to" do
    mail_bag = BaseMailer.welcome.to(["konata@luckystar.net", "kagami@luckystar.net"])
    assert_equal ["konata@luckystar.net", "kagami@luckystar.net"], mail_bag.to

    mail_bag = BaseMailer.welcome.to_bulk(["konata@luckystar.net", "kagami@luckystar.net"])
    assert_equal [["konata@luckystar.net"], ["kagami@luckystar.net"]], mail_bag.to
  end

  test "chainable mail bag call" do
    mail_bag = BaseMailer.welcome.to("konata@luckystar.net").from("kagami@luckystar.net").subject("Let's meet at the train station!")

    assert_equal ["konata@luckystar.net"], mail_bag.to
    assert_equal ["kagami@luckystar.net"], mail_bag.from
    assert_equal "Let's meet at the train station!", mail_bag.subject
  end

  test "iterates between each mail" do
    BaseMailer.welcome.each do |mail|
      assert mail
    end
  end

  test "deliver delegates to the mail object" do
    mail_bag = BaseMailer.welcome.to("konata@luckystar.net")
    mail = mail_bag.mails.first
    mail.expects(:deliver).returns(true)

    mail_bag.deliver
  end

  test "calls mails before calling mailer's method" do
    assert_raise(ActionMailer::MailBag::UnspecifiedMailerMethod) do
      BaseMailer.to("konata@luckystar.net").mails
    end
  end

  test "calls deliver before calling mailer's method" do
    assert_raise(ActionMailer::MailBag::UnspecifiedMailerMethod) do
      BaseMailer.to("konata@luckystar.net").deliver
    end
  end
end
