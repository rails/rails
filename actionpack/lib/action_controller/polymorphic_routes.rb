module ActionController
  module PolymorphicRoutes
    def polymorphic_url(record_or_hash_or_array, options = {})
      record = extract_record(record_or_hash_or_array)

      args = case record_or_hash_or_array
        when Hash: [record_or_hash_or_array[:id]]
        when Array: record_or_hash_or_array.dup
        else [record_or_hash_or_array]
        end

      args.pop # Remove the base record; we only need it in one case

      inflection =
        case
        when options[:action] == "new"
          :singular
        when record.respond_to?(:new_record?) && record.new_record?
          :plural
        else
          args.push(record) # Put the base record back in
          :singular
        end
      
      named_route = build_named_route_call(record_or_hash_or_array, inflection, options)
      send(named_route, *args)
    end

    def polymorphic_path(record_or_hash_or_array)
      polymorphic_url(record_or_hash_or_array, :routing_type => :path)
    end

    %w(edit new formatted).each do |action|
      module_eval <<-EOT, __FILE__, __LINE__
        def #{action}_polymorphic_url(record_or_hash)
          polymorphic_url(record_or_hash, :action => "#{action}")
        end

        def #{action}_polymorphic_path(record_or_hash)
          polymorphic_url(record_or_hash, :action => "#{action}", :routing_type => :path)
        end
      EOT
    end


    private
      def action_prefix(options)
        options[:action] ? "#{options[:action]}_" : ""
      end

      def routing_type(options)
        "#{options[:routing_type] || "url"}"
      end

      def build_named_route_call(records, inflection, options = {})
        records = Array.new([extract_record(records)]) unless records.is_a?(Array)
        base_segment = "#{RecordIdentifier.send("#{inflection}_class_name", records.pop)}_"

        method_root = records.reverse.inject(base_segment) do |string, name|
          segment = "#{RecordIdentifier.send("singular_class_name", name)}_"
          segment << string
        end

        action_prefix(options) + method_root + routing_type(options)
      end

      def extract_record(record_or_hash_or_array)
        case record_or_hash_or_array
          when Array: record_or_hash_or_array.last
          when Hash:  record_or_hash_or_array[:id]
          else        record_or_hash_or_array
        end
      end
  end
end
