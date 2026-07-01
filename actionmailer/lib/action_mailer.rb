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

  class << self
    # Enqueue many emails at once to be delivered through Active Job.
    # When the individual job runs, it will send the email using +deliver_now+.
    def deliver_all_later(*deliveries, **options)
      _deliver_all_later("deliver_now", *deliveries, **options)
    end

    # Enqueue many emails at once to be delivered through Active Job.
    # When the individual job runs, it will send the email using +deliver_now!+.
    # That means that the message will be sent bypassing checking +perform_deliveries+
    # and +raise_delivery_errors+, so use with caution.
    def deliver_all_later!(*deliveries, **options)
      _deliver_all_later("deliver_now!", *deliveries, **options)
    end

    def eager_load!
      super

      require "mail"
      Mail.eager_autoload!

      Base.descendants.each do |mailer|
        mailer.eager_load! unless mailer.abstract?
      end
    end

    private
      def _deliver_all_later(delivery_method, *deliveries, **options)
        deliveries = deliveries.first if deliveries.first.is_a?(Array)

        jobs = deliveries.map do |delivery|
          mailer_class = delivery.mailer_class
          delivery_job = mailer_class.delivery_job

          delivery_job
            .new(mailer_class.name, delivery.action.to_s, delivery_method, params: delivery.params, args: delivery.args)
            .set(options)
        end

        ActiveJob.perform_all_later(jobs)
      end
  end
end

autoload :Mime, "action_dispatch/http/mime_type"

ActiveSupport.on_load(:action_view) do
  ActionView::Base.default_formats ||= Mime::SET.symbols
  ActionView::Template.mime_types_implementation = Mime
  ActionView::LookupContext::DetailsKey.clear
end
