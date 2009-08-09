class Thor
  class Argument #:nodoc:
    VALID_TYPES = [ :numeric, :hash, :array, :string ]

    attr_reader :name, :description, :required, :type, :default, :banner
    alias :human_name :name

    def initialize(name, description=nil, required=true, type=:string, default=nil, banner=nil)
      class_name = self.class.name.split("::").last

      raise ArgumentError, "#{class_name} name can't be nil."                         if name.nil?
      raise ArgumentError, "Type :#{type} is not valid for #{class_name.downcase}s."  if type && !valid_type?(type)

      @name        = name.to_s
      @description = description
      @required    = required || false
      @type        = (type || :string).to_sym
      @default     = default
      @banner      = banner || default_banner

      validate! # Trigger specific validations
    end

    def usage
      required? ? banner : "[#{banner}]"
    end

    def required?
      required
    end

    def show_default?
      case default
        when Array, String, Hash
          !default.empty?
        else
          default
      end
    end

    protected

      def validate!
        raise ArgumentError, "An argument cannot be required and have default value." if required? && !default.nil?
      end

      def valid_type?(type)
        VALID_TYPES.include?(type.to_sym)
      end

      def default_banner
        case type
          when :boolean
            nil
          when :string, :default
            human_name.upcase
          when :numeric
            "N"
          when :hash
            "key:value"
          when :array
            "one two three"
        end
      end

  end
end
