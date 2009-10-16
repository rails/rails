require "active_support/string_inquirer"
require "active_support/deprecation"

RAILS_ROOT = (Class.new(ActiveSupport::Deprecation::DeprecationProxy) do
  def target
    Rails.root
  end

  def replace(val)
    puts OMG
  end

  def warn(callstack, called, args)
    msg = "RAILS_ROOT is deprecated! Use Rails.root instead."
    ActiveSupport::Deprecation.warn(msg, callstack)
  end
end).new