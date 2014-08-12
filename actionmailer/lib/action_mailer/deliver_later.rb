require 'active_job'

module ActionMailer
  module DeliverLater
    extend ActiveSupport::Autoload
    autoload :Job
    autoload :MailMessageWrapper
  end
end