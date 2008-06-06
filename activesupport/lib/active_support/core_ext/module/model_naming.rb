module ActiveSupport
  class ModelName < String
    attr_reader :singular, :plural, :partial_path

    def initialize(name)
      super
      @singular = underscore.tr('/', '_').freeze
      @plural = @singular.pluralize.freeze
      @partial_path = "#{tableize}/#{demodulize.underscore}".freeze
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
