module ActiveSupport
  class ModelName < String
    attr_reader :singular, :plural, :cache_key, :partial_path

    def initialize(name)
      super
      @singular = underscore.tr('/', '_').freeze
      @plural = @singular.pluralize.freeze
      @cache_key = tableize.freeze
      @partial_path = "#{@cache_key}/#{demodulize.underscore}".freeze
    end
  end

  module CoreExt
    module Module
      module ModelNaming
        def model_name
          @model_name ||= ModelName.new(name)
        end
      end
    end
  end
end
