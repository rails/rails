#!/usr/local/bin/ruby

require File.dirname(__FILE__) + '/../config/environments/production'

def create_mailer_class(class_name, file_name, mail_actions)
  File.open("app/models/" + file_name + ".rb", "w", 0777) do |mailer_file|
    mailer_file.write <<EOF
class #{class_name} < ActionMailer::Base
#{mail_actions.collect { |action| 
  "  def #{action}(sent_on = Time.now)\n" +
  "    @recipients = ''\n" +
  "    @from       = ''\n" +
  "    @subject    = ''\n" +
  "    @body       = { }\n" +
  "    @sent_on    = sent_on\n" +
  "  end" 
}.join "\n\n" }
end
EOF
  end
end

def create_templates(class_name, file_name, mail_actions)
  Dir.mkdir("app/views/#{file_name}") rescue nil
  mail_actions.each { |action| File.open("app/views/#{file_name}/#{action}.rhtml", "w", 0777) do |template_file|
    template_file.write <<EOF
#{class_name}##{action}
EOF
  end }
end

def create_fixtures(class_name, file_name, mail_actions)
  Dir.mkdir("test/fixtures/" + file_name) rescue nil
  mail_actions.each { |action| File.open("test/fixtures/#{file_name}/#{action}", "w", 0777) do |template_file|
    template_file.write <<EOF
#{class_name}##{action}
EOF
  end }
end


def create_test_class(class_name, file_name, mail_actions)
  File.open("test/unit/" + file_name + "_test.rb", "w", 0777) do |test_file|
    test_file.write <<EOF
require File.dirname(__FILE__) + '/../test_helper'
require '#{file_name}'

class #{class_name}Test < Test::Unit::TestCase
  def setup
    @expected = TMail::Mail.new
  end

#{mail_actions.collect { |action| 
  "  def test_#{action}\n" +
  "    @expected.to      = ''\n" +
  "    @expected.from    = ''\n" +
  "    @expected.subject = ''\n" +
  "    @expected.body    = read_notification_fixture \"#{action}\"\n" +
  "    @expected.date    = Time.now\n" +
  "    \n" +
  "    actual = #{class_name}.create_#{action}(@expected.date)\n" +
  "    \n" +
  "    assert_equal @expected.encoded, actual.encoded\n" +
  "  end" 
}.join "\n\n" }

  private
    def read_notification_fixture(name)
      IO.readlines(File.dirname(__FILE__) + "/../fixtures/#{file_name}/\#{name}").join
    end
end
EOF
  end
end


if !ARGV.empty?
  mailer_name  = ARGV[0]
  mail_actions = ARGV[1..-1]
  
  class_name = Inflector.camelize(mailer_name)
  file_name  = Inflector.underscore(mailer_name)
  
  create_mailer_class(class_name, file_name, mail_actions)
  create_templates(class_name, file_name, mail_actions)
  create_fixtures(class_name, file_name, mail_actions)
  create_test_class(class_name, file_name, mail_actions)
else
  puts <<-END_HELP

NAME
     new_mailer - create mailer and view stub files

SYNOPSIS
     new_mailer [mailer_name] [mail_actions ...]

DESCRIPTION
     The new_mailer generator takes the name of the new mailer class as the
     first argument and a variable number of mail action names as subsequent arguments.
     
     From the passed arguments, new_mailer generates a class file in
     app/models with a mail action for each of the mail action names passed.
     It then creates a mail test suite in test/unit with one stub test case and one
     stub fixture per mail action. Finally, it creates a template stub for each of the
     mail action names in app/views under a directory with the same name as the class.
     
EXAMPLE
     new_mailer Notifications signup forgot_password invoice
     
     This will generate a Notifications class in
     app/models/notifications.rb, a NotificationsTest in
     test/unit/notifications_test.rb, and signup, forgot_password, and invoice
     in test/fixture/notification. It will also create signup.rhtml,
     forgot_password.rhtml, and invoice.rhtml in app/views/notifications.
     
     The Notifications class will have the following methods: signup, forgot_password, 
     and invoice.
END_HELP
end