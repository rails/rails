module ActionMailbox::InboundEmail::Incineratable
  extend ActiveSupport::Concern

  included do
    after_update_commit :incinerate_later, if: -> { status_previously_changed? && processed? }
  end

  def incinerate_later
    ActionMailbox::IncinerationJob.schedule self
  end

  def incinerate
    Incineration.new(self).run
  end
end
