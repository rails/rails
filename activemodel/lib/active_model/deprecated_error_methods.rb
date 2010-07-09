module ActiveModel
  module DeprecatedErrorMethods
    def on(attribute)
      message = "Errors#on have been deprecated, use Errors#[] instead.\n"
      message << "Also note that the behaviour of Errors#[] has changed. Errors#[] now always returns an Array. An empty Array is "
      message << "returned when there are no errors on the specified attribute."
      ActiveSupport::Deprecation.warn(message)

      errors = self[attribute]
      errors.size < 2 ? errors.first : errors
    end

    def on_base
      ActiveSupport::Deprecation.warn "Errors#on_base have been deprecated, use Errors#[:base] instead"
      ActiveSupport::Deprecation.silence { on(:base) }
    end

    def add_to_base(msg)
      ActiveSupport::Deprecation.warn "Errors#add_to_base(msg) has been deprecated, use Errors#add(:base, msg) instead"
      self[:base] << msg
    end

    def invalid?(attribute)
      ActiveSupport::Deprecation.warn "Errors#invalid?(attribute) has been deprecated, use Errors#[attribute].any? instead"
      self[attribute].any?
    end

    def each_full
      ActiveSupport::Deprecation.warn "Errors#each_full has been deprecated, use Errors#to_a.each instead"
      to_a.each { |error| yield error }
    end
  end
end
