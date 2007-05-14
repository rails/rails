module ActionController
  module PolymorphicRoutes
    extend self

    def polymorphic_url(record_or_hash, url_writer, options = {})
      record = extract_record(record_or_hash)

      case
      when options[:action] == "new"
        url_writer.send(
          action_prefix(options) + RecordIdentifier.singular_class_name(record) + routing_type(options)
        )

      when record.respond_to?(:new_record?) && record.new_record?
        url_writer.send(
          action_prefix(options) + RecordIdentifier.plural_class_name(record) + routing_type(options)
        )

      else
        url_writer.send(
          action_prefix(options) + RecordIdentifier.singular_class_name(record) + routing_type(options), record_or_hash
        )
      end
    end

    def polymorphic_path(record_or_hash, url_writer)
      polymorphic_url(record_or_hash, url_writer, :routing_type => :path)
    end

    %w( edit new formatted ).each do |action|
      module_eval <<-EOT
        def #{action}_polymorphic_url(record_or_hash, url_writer)
          polymorphic_url(record_or_hash, url_writer, :action => "#{action}")
        end

        def #{action}_polymorphic_path(record_or_hash, url_writer)
          polymorphic_url(record_or_hash, url_writer, :action => "#{action}", :routing_type => :path)
        end
      EOT
    end


    private
      def action_prefix(options)
        options[:action] ? "#{options[:action]}_" : ""
      end
      
      def routing_type(options)
        "_#{options[:routing_type] || "url"}"
      end
      
      def extract_record(record_or_hash)
        record_or_hash.is_a?(Hash) ? record_or_hash[:id] : record_or_hash
      end
  end
end