module ActionDispatch
  class IntegrationTest < IntegrationTestCase
    def initialize(*)
      ActiveSupport::Deprecation.warn(<<-MSG.squish)
        ActionDispatch::IntegrationTest has been renamed ActionDispatch::IntegrationTestCase.
        ActionDispatch::IntegrationTest will be removed in Rails 6.0.
        Please use ActionDispatch::IntegrationTestCase adapter instead.
      MSG

      super
    end
  end
end
