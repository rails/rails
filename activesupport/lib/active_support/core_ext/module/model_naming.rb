require 'active_support/inflector'

module ActiveSupport
  class ModelName < String
    attr_reader :singular, :plural, :cache_key, :partial_path

    def initialize(name)
      super
      @singular = ActiveSupport::Inflector.underscore(self).tr('/', '_').freeze
      @plural = ActiveSupport::Inflector.pluralize(@singular).freeze
      @cache_key = tableize.freeze
      @partial_path = "#{@cache_key}/#{ActiveSupport::Inflector.underscore(ActiveSupport::Inflector.demodulize(self))}".freeze
    end
  end
end

class Module
  # Returns an ActiveSupport::ModelName object for module. It can be
  # used to retrieve all kinds of naming-related information.
  def model_name
    @model_name ||= ActiveSupport::ModelName.new(name)
  end
end
