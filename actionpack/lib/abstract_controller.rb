require 'action_pack'
require 'active_support/rails'
require 'active_support/core_ext/module/attr_internal'
require 'active_support/core_ext/module/anonymous'
require 'active_support/i18n'

module AbstractController
  extend ActiveSupport::Autoload

  autoload :Base
  autoload :Callbacks
  autoload :Collector
  autoload :DoubleRenderError, "abstract_controller/rendering.rb"
  autoload :Helpers
  autoload :Logger
  autoload :Translation
  autoload :AssetPaths
  autoload :UrlFor
end
