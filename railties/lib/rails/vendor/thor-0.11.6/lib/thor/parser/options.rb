class Thor
  # This is a modified version of Daniel Berger's Getopt::Long class, licensed
  # under Ruby's license.
  #
  class Options < Arguments #:nodoc:
    LONG_RE     = /^(--\w+[-\w+]*)$/
    SHORT_RE    = /^(-[a-z])$/i
    EQ_RE       = /^(--\w+[-\w+]*|-[a-z])=(.*)$/i
    SHORT_SQ_RE = /^-([a-z]{2,})$/i # Allow either -x -v or -xv style for single char args
    SHORT_NUM   = /^(-[a-z])#{NUMERIC}$/i

    # Receives a hash and makes it switches.
    #
    def self.to_switches(options)
      options.map do |key, value|
        case value
          when true
            "--#{key}"
          when Array
            "--#{key} #{value.map{ |v| v.inspect }.join(' ')}"
          when Hash
            "--#{key} #{value.map{ |k,v| "#{k}:#{v}" }.join(' ')}"
          when nil, false
            ""
          else
            "--#{key} #{value.inspect}"
        end
      end.join(" ")
    end

    # Takes a hash of Thor::Option objects.
    #
    def initialize(options={})
      options = options.values
      super(options)
      @shorts, @switches = {}, {}

      options.each do |option|
        @switches[option.switch_name] = option

        option.aliases.each do |short|
          @shorts[short.to_s] ||= option.switch_name
        end
      end
    end

    def parse(args)
      @pile = args.dup

      while peek
        if current_is_switch?
          case shift
            when SHORT_SQ_RE
              unshift($1.split('').map { |f| "-#{f}" })
              next
            when EQ_RE, SHORT_NUM
              unshift($2)
              switch = $1
            when LONG_RE, SHORT_RE
              switch = $1
          end

          switch = normalize_switch(switch)
          next unless option = switch_option(switch)

          @assigns[option.human_name] = parse_peek(switch, option)
        else
          shift
        end
      end

      check_requirement!
      @assigns
    end

    protected

      # Returns true if the current value in peek is a registered switch.
      #
      def current_is_switch?
        case peek
          when LONG_RE, SHORT_RE, EQ_RE, SHORT_NUM
            switch?($1)
          when SHORT_SQ_RE
            $1.split('').any? { |f| switch?("-#{f}") }
        end
      end

      def switch?(arg)
        switch_option(arg) || @shorts.key?(arg)
      end

      def switch_option(arg)
        if match = no_or_skip?(arg)
          @switches[arg] || @switches["--#{match}"]
        else
          @switches[arg]
        end
      end

      def no_or_skip?(arg)
        arg =~ /^--(no|skip)-([-\w]+)$/
        $2
      end

      # Check if the given argument is actually a shortcut.
      #
      def normalize_switch(arg)
        @shorts.key?(arg) ? @shorts[arg] : arg
      end

      # Parse boolean values which can be given as --foo=true, --foo or --no-foo.
      #
      def parse_boolean(switch)
        if current_is_value?
          ["true", "TRUE", "t", "T", true].include?(shift)
        else
          @switches.key?(switch) || !no_or_skip?(switch)
        end
      end

      # Parse the value at the peek analyzing if it requires an input or not.
      #
      def parse_peek(switch, option)
        unless current_is_value?
          if option.boolean?
            # No problem for boolean types
          elsif no_or_skip?(switch)
            return nil # User set value to nil
          elsif option.string? && !option.required?
            return option.human_name # Return the option name
          else
            raise MalformattedArgumentError, "no value provided for option '#{switch}'"
          end
        end

        @non_assigned_required.delete(option)
        send(:"parse_#{option.type}", switch)
      end

  end
end
