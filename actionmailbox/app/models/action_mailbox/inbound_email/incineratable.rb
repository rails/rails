# frozen_string_literal: true

# Ensure that the +InboundEmail+ is automatically scheduled for later incineration if the status has been
# changed to +processed+. The later incineration will be invoked at the time specified by the
# +ActionMailbox.incinerate_after+ time using the +IncinerationJob+.
module ActionMailbox::InboundEmail::Incineratable
  extend ActiveSupport::Concern

  included do
    after_update_commit :incinerate_later, if: -> { ActionMailbox.incinerate && status_previously_changed? && processed? }
  end

  def incinerate_later
    ActionMailbox::IncinerationJob.schedule self
  end

  def incinerate
    Incineration.new(self).run
  end
end
