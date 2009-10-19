module ActiveRecord
  module Type
    class Serialize < Object

      def cast(value)
        unserialize(value)
      end

      def appendable?
        true
      end

      protected

      def unserialize(value)
        unserialized_object = object_from_yaml(value)

        if unserialized_object.is_a?(@options[:serialize]) || unserialized_object.nil?
          unserialized_object
        else
          raise SerializationTypeMismatch,
            "#{name} was supposed to be a #{@options[:serialize]}, but was a #{unserialized_object.class.to_s}"
        end
      end

      def object_from_yaml(string)
        return string unless string.is_a?(String) && string =~ /^---/
        YAML::load(string) rescue string
      end

    end
  end
end