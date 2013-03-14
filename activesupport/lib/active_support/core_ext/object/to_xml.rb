require 'active_support/xml_mini' unless defined?(XmlMini)

(ActiveSupport::XmlMini::TYPE_NAMES.keys.collect(&:constantize) - [Array, Hash] + [NilClass]).each do |klass|
  klass.class_eval do

    def to_xml(options = {})
      require 'active_support/builder' unless defined?(Builder)

      options = options.dup
      options[:indent]      ||= 2
      options[:builder]     ||= Builder::XmlMarkup.new(indent: options[:indent])
      options[:root]        ||= 'object'
      options[:skip_to_xml]   = true

      builder = options[:builder]
      builder.instruct! unless options.delete(:skip_instruct)
      root = ActiveSupport::XmlMini.rename_key(options[:root].to_s, options)

      ActiveSupport::XmlMini.to_tag(root, self, options)
    end

  end
end
