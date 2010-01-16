require 'active_support/core_ext/hash/reverse_merge'

module ActiveModel
  module Translation
    include ActiveModel::Naming

    # Returns the i18n_scope for the class. Overwrite if you want custom lookup.
    def i18n_scope
      :activemodel
    end

    # When localizing a string, goes through the lookup returned by this method.
    # Used in ActiveModel::Name#human, ActiveModel::Errors#full_messages and
    # ActiveModel::Translation#human_attribute_name.
    def lookup_ancestors
      self.ancestors.select { |x| x.respond_to?(:model_name) }
    end

    # Transforms attributes names into a more human format, such as "First name" instead of "first_name".
    #
    # Example:
    #
    #   Person.human_attribute_name("first_name") # => "First name"
    #
    # Specify +options+ with additional translating options.
    def human_attribute_name(attribute, options = {})
      defaults = lookup_ancestors.map do |klass|
        :"#{self.i18n_scope}.attributes.#{klass.model_name.underscore}.#{attribute}"
      end

      defaults << :"attributes.#{attribute}"
      defaults << options.delete(:default) if options[:default]
      defaults << attribute.to_s.humanize

      options.reverse_merge! :count => 1, :default => defaults
      I18n.translate(defaults.shift, options)
    end

    # Model.human_name is deprecated. Use Model.model_name.human instead.
    def human_name(*args)
      ActiveSupport::Deprecation.warn("human_name has been deprecated, please use model_name.human instead", caller[0,5])
      model_name.human(*args)
    end
  end
end
