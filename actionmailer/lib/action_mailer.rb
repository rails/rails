# frozen_string_literal: true

#--
# Copyright (c) David Heinemeier Hansson
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

require "abstract_controller"
require "action_mailer/version"
require "action_mailer/deprecator"

# Common Active Support usage in Action Mailer
require "active_support"
require "active_support/rails"
require "active_support/core_ext/class"
require "active_support/core_ext/module/attr_internal"
require "active_support/core_ext/string/inflections"
require "active_support/lazy_load_hooks"

# :include: ../README.rdoc
module ActionMailer
  extend ::ActiveSupport::Autoload

  eager_autoload do
    autoload :Collector
  end

  autoload :Base
  autoload :Callbacks
  autoload :DeliveryMethods
  autoload :InlinePreviewInterceptor
  autoload :MailHelper
  autoload :Parameterized
  autoload :Preview
  autoload :Previews, "action_mailer/preview"
  autoload :TestCase
  autoload :TestHelper
  autoload :MessageDelivery
  autoload :MailDeliveryJob
  autoload :QueuedDelivery
  autoload :FormBuilder

  def self.eager_load!
    super

    require "mail"
    Mail.eager_autoload!

    Base.descendants.each do |mailer|
      mailer.eager_load! unless mailer.abstract?
    end
  end
end

autoload :Mime, "action_dispatch/http/mime_type"

ActiveSupport.on_load(:action_view) do
  ActionView::Base.default_formats ||= Mime::SET.symbols
  ActionView::Template.mime_types_implementation = Mime
  ActionView::LookupContext::DetailsKey.clear
end
