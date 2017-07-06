require "active_record"
require "active_storage/railtie" if defined?(Rails)

module ActiveStorage
  extend ActiveSupport::Autoload

  autoload :Blob
  autoload :Site
end
