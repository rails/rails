module ActionMailbox::InboundEmail::Incineratable
  extend ActiveSupport::Concern

  # TODO: Extract into framework configuration
  INCINERATABLE_AFTER = 30.days

  included do
    before_update :remember_to_incinerate_later
    after_update_commit :incinerate_later, if: :incinerating_later?
  end

  def incinerate
    Incineration.new(self).run
  end

  private
    # TODO: Use enum change tracking once merged into Active Support
    def remember_to_incinerate_later
      if status_changed? && (delivered? || failed?)
        @incinerating_later = true
      end
    end

    def incinerating_later?
      @incinerating_later ||= false
    end

    def incinerate_later
      ActionMailbox::InboundEmail::IncinerationJob.schedule(self)
    end
end
