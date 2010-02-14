require "active_support/string_inquirer"
require "active_support/deprecation"

RAILS_ROOT = (Class.new(ActiveSupport::Deprecation::DeprecationProxy) do
  cattr_accessor :warned
  self.warned = false

  def target
    Rails.root
  end

  def replace(*args)
    warn(caller, :replace, *args)
  end

  def warn(callstack, called, args)
    unless warned
      ActiveSupport::Deprecation.warn("RAILS_ROOT is deprecated! Use Rails.root instead", callstack)
      self.warned = true
    end
  end
end).new

RAILS_ENV = (Class.new(ActiveSupport::Deprecation::DeprecationProxy) do
  cattr_accessor :warned
  self.warned = false

  def target
    Rails.env
  end

  def replace(*args)
    warn(caller, :replace, *args)
  end

  def warn(callstack, called, args)
    unless warned
      ActiveSupport::Deprecation.warn("RAILS_ENV is deprecated! Use Rails.env instead", callstack)
      self.warned = true
    end
  end
end).new

RAILS_DEFAULT_LOGGER = (Class.new(ActiveSupport::Deprecation::DeprecationProxy) do
  cattr_accessor :warned
  self.warned = false

  def target
    Rails.logger
  end

  def replace(*args)
    warn(caller, :replace, *args)
  end

  def warn(callstack, called, args)
    unless warned
      ActiveSupport::Deprecation.warn("RAILS_DEFAULT_LOGGER is deprecated! Use Rails.logger instead", callstack)
      self.warned = true
    end
  end
end).new
