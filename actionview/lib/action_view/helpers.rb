# frozen_string_literal: true

require "active_support/benchmarkable"

module ActionView #:nodoc:
  module Helpers #:nodoc:
    extend ActiveSupport::Autoload

    autoload :ActiveModelHelper
    autoload :AssetTagHelper
    autoload :AssetUrlHelper
    autoload :AtomFeedHelper
    autoload :CacheHelper
    autoload :CaptureHelper
    autoload :ControllerHelper
    autoload :CspHelper
    autoload :CsrfHelper
    autoload :DateHelper
    autoload :DebugHelper
    autoload :FormHelper
    autoload :FormOptionsHelper
    autoload :FormTagHelper
    autoload :JavaScriptHelper, "action_view/helpers/javascript_helper"
    autoload :NumberHelper
    autoload :OutputSafetyHelper
    autoload :RecordTagHelper
    autoload :RenderingHelper
    autoload :SanitizeHelper
    autoload :TagHelper
    autoload :TextHelper
    autoload :TranslationHelper
    autoload :UrlHelper
    autoload :Tags

    def self.eager_load!
      super
      Tags.eager_load!
    end

    extend ActiveSupport::Concern

    include ActiveSupport::Benchmarkable
    include ActiveModelHelper
    include AssetTagHelper
    include AssetUrlHelper
    include AtomFeedHelper
    include CacheHelper
    include CaptureHelper
    include ControllerHelper
    include CspHelper
    include CsrfHelper
    include DateHelper
    include DebugHelper
    include FormHelper
    include FormOptionsHelper
    include FormTagHelper
    include JavaScriptHelper
    include NumberHelper
    include OutputSafetyHelper
    include RecordTagHelper
    include RenderingHelper
    include SanitizeHelper
    include TagHelper
    include TextHelper
    include TranslationHelper
    include UrlHelper
  end
end
