require "active_record"
require "active_vault/railtie" if defined?(Rails)

module ActiveVault
  extend ActiveSupport::Autoload

  autoload :Blob
  autoload :Site
end
