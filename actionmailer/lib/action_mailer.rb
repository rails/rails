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
  extend ::ActiveSupport::Autoload

  autoload :AdvAttrAccessor
  autoload :DeprecatedBody
  autoload :Base
  autoload :DeliveryMethod
  autoload :MailHelper
  autoload :Part
  autoload :PartContainer
  autoload :Quoting
  autoload :TestHelper
  autoload :Utils
end

module Text
  extend ActiveSupport::Autoload

  autoload :Format, 'action_mailer/vendor/text_format'
end

module Net
  extend ActiveSupport::Autoload

  autoload :SMTP
end


require 'action_mailer/vendor/tmail'
