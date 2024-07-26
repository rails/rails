#!/usr/local/bin/ruby
require File.dirname(__FILE__) + '/../config/environments/production'
require 'generator'

unless ARGV.empty?
  rails_root = File.dirname(__FILE__) + '/..'
  name       = ARGV.shift
  actions    = ARGV
  Generator::Mailer.new(rails_root, name, actions).generate
else
  puts <<-END_HELP

NAME
     new_mailer - create mailer and view stub files

SYNOPSIS
     new_mailer MailerName action [action ...]

DESCRIPTION
     The new_mailer generator takes the name of the new mailer class as the
     first argument and a variable number of mail action names as subsequent
     arguments.

     From the passed arguments, new_mailer generates a class file in
     app/models with a mail action for each of the mail action names passed.
     It then creates a mail test suite in test/unit with one stub test case
     and one stub fixture per mail action. Finally, it creates a template stub
     for each of the mail action names in app/views under a directory with the
     same name as the class.

EXAMPLE
     new_mailer Notifications signup forgot_password invoice

     This will generate a Notifications class in
     app/models/notifications.rb, a NotificationsTest in
     test/unit/notifications_test.rb, and signup, forgot_password, and invoice
     in test/fixture/notification. It will also create signup.rhtml,
     forgot_password.rhtml, and invoice.rhtml in app/views/notifications.
     
     The Notifications class will have the following methods: signup,
     forgot_password, and invoice.
END_HELP
end
