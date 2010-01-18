require "active_support/string_inquirer"
require "active_support/deprecation"

RAILS_ROOT = (Class.new(ActiveSupport::Deprecation::DeprecationProxy) do
  def target
    Rails.root
  end

  def replace(*args)
    warn(caller, :replace, *args)
  end

  def warn(callstack, called, args)
    msg = "RAILS_ROOT is deprecated! Use Rails.root instead"
    ActiveSupport::Deprecation.warn(msg, callstack)
  end
end).new

RAILS_ENV = (Class.new(ActiveSupport::Deprecation::DeprecationProxy) do
  def target
    Rails.env
  end

  def replace(*args)
    warn(caller, :replace, *args)
  end

  def warn(callstack, called, args)
    msg = "RAILS_ENV is deprecated! Use Rails.env instead"
    ActiveSupport::Deprecation.warn(msg, callstack)
  end
end).new

RAILS_DEFAULT_LOGGER = (Class.new(ActiveSupport::Deprecation::DeprecationProxy) do
  def target
    Rails.logger
  end

  def replace(*args)
    warn(caller, :replace, *args)
  end

  def warn(callstack, called, args)
    msg = "RAILS_DEFAULT_LOGGER is deprecated! Use Rails.logger instead"
    ActiveSupport::Deprecation.warn(msg, callstack)
  end
end).new
