require 'active_support/inflector'

module ActiveModel
  class Name < String
    attr_reader :singular, :plural, :element, :collection, :partial_path, :human
    alias_method :cache_key, :collection

    def initialize(klass, name)
      super(name)
      @klass = klass
      @singular = ActiveSupport::Inflector.underscore(self).tr('/', '_').freeze
      @plural = ActiveSupport::Inflector.pluralize(@singular).freeze
      @element = ActiveSupport::Inflector.underscore(ActiveSupport::Inflector.demodulize(self)).freeze
      @human = ActiveSupport::Inflector.humanize(@element).freeze
      @collection = ActiveSupport::Inflector.tableize(self).freeze
      @partial_path = "#{@collection}/#{@element}".freeze
    end
  end

  module Naming
    # Returns an ActiveModel::Name object for module. It can be
    # used to retrieve all kinds of naming-related information.
    def model_name
      @_model_name ||= ActiveModel::Name.new(self, name)
    end
  end
end
