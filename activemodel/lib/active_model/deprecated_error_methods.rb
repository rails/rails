module ActiveModel
  module DeprecatedErrorMethods
    def on(attribute)
      ActiveSupport::Deprecation.warn "Errors#on have been deprecated, use Errors#[] instead"
      self[attribute]
    end

    def on_base
      ActiveSupport::Deprecation.warn "Errors#on_base have been deprecated, use Errors#[:base] instead"
      on(:base)
    end

    def add(attribute, msg = Errors.default_error_messages[:invalid])
      ActiveSupport::Deprecation.warn "Errors#add(attribute, msg) has been deprecated, use Errors#[attribute] << msg instead"
      self[attribute] << msg
    end

    def add_to_base(msg)
      ActiveSupport::Deprecation.warn "Errors#add_to_base(msg) has been deprecated, use Errors#[:base] << msg instead"
      self[:base] << msg
    end
  
    def invalid?(attribute)
      ActiveSupport::Deprecation.warn "Errors#invalid?(attribute) has been deprecated, use Errors#[attribute].any? instead"
      self[attribute].any?
    end

    def full_messages
      ActiveSupport::Deprecation.warn "Errors#full_messages has been deprecated, use Errors#to_a instead"
      to_a
    end

    def each_full
      ActiveSupport::Deprecation.warn "Errors#each_full has been deprecated, use Errors#to_a.each instead"
      to_a.each { |error| yield error }
    end
  end
end