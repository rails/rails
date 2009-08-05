class Thor
  class Arguments #:nodoc:
    NUMERIC = /(\d*\.\d+|\d+)/

    # Receives an array of args and returns two arrays, one with arguments
    # and one with switches.
    #
    def self.split(args)
      arguments = []

      args.each do |item|
        break if item =~ /^-/
        arguments << item
      end

      return arguments, args[Range.new(arguments.size, -1)]
    end

    def self.parse(base, args)
      new(base).parse(args)
    end

    # Takes an array of Thor::Argument objects.
    #
    def initialize(arguments=[])
      @assigns, @non_assigned_required = {}, []
      @switches = arguments

      arguments.each do |argument|
        if argument.default
          @assigns[argument.human_name] = argument.default
        elsif argument.required?
          @non_assigned_required << argument
        end
      end
    end

    def parse(args)
      @pile = args.dup

      @switches.each do |argument|
        break unless peek
        @non_assigned_required.delete(argument)
        @assigns[argument.human_name] = send(:"parse_#{argument.type}", argument.human_name)
      end

      check_requirement!
      @assigns
    end

    private

      def peek
        @pile.first
      end

      def shift
        @pile.shift
      end

      def unshift(arg)
        unless arg.kind_of?(Array)
          @pile.unshift(arg)
        else
          @pile = arg + @pile
        end
      end

      def current_is_value?
        peek && peek.to_s !~ /^-/
      end

      # Runs through the argument array getting strings that contains ":" and
      # mark it as a hash:
      #
      #   [ "name:string", "age:integer" ]
      #
      # Becomes:
      #
      #   { "name" => "string", "age" => "integer" }
      #
      def parse_hash(name)
        return shift if peek.is_a?(Hash)
        hash = {}

        while current_is_value? && peek.include?(?:)
          key, value = shift.split(':')
          hash[key] = value
        end
        hash
      end

      # Runs through the argument array getting all strings until no string is
      # found or a switch is found.
      #
      #   ["a", "b", "c"]
      #
      # And returns it as an array:
      #
      #   ["a", "b", "c"]
      #
      def parse_array(name)
        return shift if peek.is_a?(Array)
        array = []

        while current_is_value?
          array << shift
        end
        array
      end

      # Check if the peel is numeric ofrmat and return a Float or Integer.
      # Otherwise raises an error.
      #
      def parse_numeric(name)
        return shift if peek.is_a?(Numeric)

        unless peek =~ NUMERIC && $& == peek
          raise MalformattedArgumentError, "expected numeric value for '#{name}'; got #{peek.inspect}"
        end

        $&.index('.') ? shift.to_f : shift.to_i
      end

      # Parse string, i.e., just return the current value in the pile.
      #
      def parse_string(name)
        shift
      end

      # Raises an error if @non_assigned_required array is not empty.
      #
      def check_requirement!
        unless @non_assigned_required.empty?
          names = @non_assigned_required.map do |o|
            o.respond_to?(:switch_name) ? o.switch_name : o.human_name
          end.join("', '")

          class_name = self.class.name.split('::').last.downcase
          raise RequiredArgumentMissingError, "no value provided for required #{class_name} '#{names}'"
        end
      end

  end
end
