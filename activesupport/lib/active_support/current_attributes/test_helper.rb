# frozen_string_literal: true

module ActiveSupport::CurrentAttributes::TestHelper # :nodoc:
  def before_setup
    ActiveSupport::CurrentAttributes.clear_all
    super
  end

  def after_teardown
    super
    ActiveSupport::CurrentAttributes.clear_all
  end
end
