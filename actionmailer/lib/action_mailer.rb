#--
# Copyright (c) 2004-2009 David Heinemeier Hansson
#
# Permission is hereby granted, free of charge, to any person obtaining
# a copy of this software and associated documentation files (the
# "Software"), to deal in the Software without restriction, including
# without limitation the rights to use, copy, modify, merge, publish,
# distribute, sublicense, and/or sell copies of the Software, and to
# permit persons to whom the Software is furnished to do so, subject to
# the following conditions:
#
# The above copyright notice and this permission notice shall be
# included in all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
# EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
# MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
# NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE
# LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION
# OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION
# WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
#++

actionpack_path = "#{File.dirname(__FILE__)}/../../actionpack/lib"
$:.unshift(actionpack_path) if File.directory?(actionpack_path)
require 'action_controller'
require 'action_view'

module ActionMailer
  def self.load_all!
    [Base, Part, ::Text::Format, ::Net::SMTP]
  end

  autoload :AdvAttrAccessor, 'action_mailer/adv_attr_accessor'
  autoload :Base, 'action_mailer/base'
  autoload :Helpers, 'action_mailer/helpers'
  autoload :Part, 'action_mailer/part'
  autoload :PartContainer, 'action_mailer/part_container'
  autoload :Quoting, 'action_mailer/quoting'
  autoload :TestCase, 'action_mailer/test_case'
  autoload :TestHelper, 'action_mailer/test_helper'
  autoload :Utils, 'action_mailer/utils'
end

module Text
  autoload :Format, 'action_mailer/vendor/text_format'
end

module Net
  autoload :SMTP, 'net/smtp'
end

autoload :MailHelper, 'action_mailer/mail_helper'

require 'action_mailer/vendor/tmail'
