# frozen_string_literal: true

module ActiveRecord::QueryLogs::TestHelper # :nodoc:
  def before_setup
    ActiveRecord::QueryLogs.clear_context
    super
  end

  def after_teardown
    super
    ActiveRecord::QueryLogs.clear_context
  end
end
