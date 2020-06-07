# frozen_string_literal: true

module ActiveSupport::CurrentAttributes::TestHelper # :nodoc:
  def before_setup
    ActiveSupport::CurrentAttributes.reset_all
    super
  end

  def before_teardown
    ActiveSupport::CurrentAttributes.reset_all
    super
  end
end
