Dir.entries(File.expand_path("#{File.dirname(__FILE__)}/helpers")).sort.each do |file|
  next unless file =~ /^([a-z][a-z_]*_helper).rb$/
  require "action_view/helpers/#{$1}"
end

module ActionView #:nodoc:
  module Helpers #:nodoc:
    def self.included(base)
      base.extend(ClassMethods)
    end

    module ClassMethods
      include SanitizeHelper::ClassMethods
    end

    include ActiveRecordHelper
    include AssetTagHelper
    include AtomFeedHelper
    include BenchmarkHelper
    include CacheHelper
    include CaptureHelper
    include DateHelper
    include DebugHelper
    include FormHelper
    include FormOptionsHelper
    include FormTagHelper
    include NumberHelper
    include PrototypeHelper
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
