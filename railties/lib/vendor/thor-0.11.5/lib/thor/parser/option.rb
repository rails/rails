class Thor
  class Option < Argument #:nodoc:
    attr_reader :aliases, :group

    VALID_TYPES = [:boolean, :numeric, :hash, :array, :string]

    def initialize(name, description=nil, required=nil, type=nil, default=nil, banner=nil, group=nil, aliases=nil)
      super(name, description, required, type, default, banner)
      @aliases = [*aliases].compact
      @group   = group.to_s.capitalize if group
    end

    # This parse quick options given as method_options. It makes several
    # assumptions, but you can be more specific using the option method.
    #
    #   parse :foo => "bar"
    #   #=> Option foo with default value bar
    #
    #   parse [:foo, :baz] => "bar"
    #   #=> Option foo with default value bar and alias :baz
    #
    #   parse :foo => :required
    #   #=> Required option foo without default value
    #
    #   parse :foo => 2
    #   #=> Option foo with default value 2 and type numeric
    #
    #   parse :foo => :numeric
    #   #=> Option foo without default value and type numeric
    #
    #   parse :foo => true
    #   #=> Option foo with default value true and type boolean
    #
    # The valid types are :boolean, :numeric, :hash, :array and :string. If none
    # is given a default type is assumed. This default type accepts arguments as
    # string (--foo=value) or booleans (just --foo).
    #
    # By default all options are optional, unless :required is given.
    # 
    def self.parse(key, value)
      if key.is_a?(Array)
        name, *aliases = key
      else
        name, aliases = key, []
      end

      name    = name.to_s
      default = value

      type = case value
        when Symbol
          default  = nil

          if VALID_TYPES.include?(value)
            value
          elsif required = (value == :required)
            :string
          elsif value == :optional
            # TODO Remove this warning in the future.
            warn "Optional type is deprecated. Choose :boolean or :string instead. Assumed to be :boolean."
            :boolean
          end
        when TrueClass, FalseClass
          :boolean
        when Numeric
          :numeric
        when Hash, Array, String
          value.class.name.downcase.to_sym
      end

      self.new(name.to_s, nil, required, type, default, nil, nil, aliases)
    end

    def switch_name
      @switch_name ||= dasherized? ? name : dasherize(name)
    end

    def human_name
      @human_name ||= dasherized? ? undasherize(name) : name
    end

    def usage(padding=0)
      sample = if banner && !banner.to_s.empty?
        "#{switch_name}=#{banner}"
      else
        switch_name
      end

      sample = "[#{sample}]" unless required?

      if aliases.empty?
        (" " * padding) << sample
      else
        "#{aliases.join(', ')}, #{sample}"
      end
    end

    # Allow some type predicates as: boolean?, string? and etc.
    #
    def method_missing(method, *args, &block)
      given = method.to_s.sub(/\?$/, '').to_sym
      if valid_type?(given)
        self.type == given
      else
        super
      end
    end

    protected

      def validate!
        raise ArgumentError, "An option cannot be boolean and required." if boolean? && required?
      end

      def valid_type?(type)
        VALID_TYPES.include?(type.to_sym)
      end

      def dasherized?
        name.index('-') == 0
      end

      def undasherize(str)
        str.sub(/^-{1,2}/, '')
      end

      def dasherize(str)
        (str.length > 1 ? "--" : "-") + str.gsub('_', '-')
      end

  end
end
