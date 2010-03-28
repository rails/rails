require 'active_support/benchmarkable'

module ActionView #:nodoc:
  module Helpers #:nodoc:
    extend ActiveSupport::Autoload

    autoload :ActiveModelHelper
    autoload :AssetTagHelper
    autoload :AtomFeedHelper
    autoload :CacheHelper
    autoload :CaptureHelper
    autoload :CsrfHelper
    autoload :DateHelper
    autoload :DebugHelper
    autoload :DeprecatedBlockHelpers
    autoload :FormHelper
    autoload :FormOptionsHelper
    autoload :FormTagHelper
    autoload :JavaScriptHelper, "action_view/helpers/javascript_helper"
    autoload :NumberHelper
    autoload :PrototypeHelper
    autoload :RawOutputHelper
    autoload :RecordIdentificationHelper
    autoload :RecordTagHelper
    autoload :SanitizeHelper
    autoload :ScriptaculousHelper
    autoload :TagHelper
    autoload :TextHelper
    autoload :TranslationHelper
    autoload :UrlHelper

    def self.included(base)
      base.extend(ClassMethods)
    end

    module ClassMethods
      include SanitizeHelper::ClassMethods
    end

    include ActiveSupport::Benchmarkable

    include ActiveModelHelper
    include AssetTagHelper
    include AtomFeedHelper
    include CacheHelper
    include CaptureHelper
    include CsrfHelper
    include DateHelper
    include DebugHelper
    include FormHelper
    include FormOptionsHelper
    include FormTagHelper
    include JavaScriptHelper
    include NumberHelper
    include PrototypeHelper
    include RawOutputHelper
    include RecordIdentificationHelper
    include RecordTagHelper
    include SanitizeHelper
    include ScriptaculousHelper
    include TagHelper
    include TextHelper
    include TranslationHelper
    include UrlHelper
  end
end
