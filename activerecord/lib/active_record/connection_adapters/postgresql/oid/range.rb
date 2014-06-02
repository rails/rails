module ActiveRecord
  module ConnectionAdapters
    module PostgreSQL
      module OID # :nodoc:
        class Range < Type::Value
          attr_reader :subtype, :type

          def initialize(subtype, type)
            @subtype = subtype
            @type = type
          end

          def extract_bounds(value)
            if value.is_a?(::Range)
              {
                from:           value.begin,
                to:             value.end,
                exclude_start:  false,
                exclude_end:    value.exclude_end?
              }
            else
              from, to = value[1..-2].split(',')
              {
                from:          (value[1] == ',' || from == '-infinity') ? nil : from,
                to:            (value[-2] == ',' || to == 'infinity') ? nil : to,
                exclude_start: (value[0] == '('),
                exclude_end:   (value[-1] == ')')
              }
            end
          end

          def cast_value(value)
            return if value == 'empty'
            return value if value.is_a?(PGRange)

            extracted = extract_bounds(value)
            from = @subtype.type_cast(extracted[:from])
            to = @subtype.type_cast(extracted[:to])

            PGRange.new(from, to, @subtype.type, extracted)
          end
        end
      end

      class PGRange
        attr_reader :from, :to, :subtype, :exclude_start, :exclude_end
        delegate :bsearch, :each, :last, to: :to_range
        
        def initialize(from, to, subtype, opts={})
          @from, @to = from, to
          @subtype = subtype
          # PostgreSQL automatically makes any unbounded start/end exclusive
          @exclude_start = !!opts[:exclude_start] || @from.nil?
          @exclude_end = !!opts[:exclude_end] || @to.nil?
        end

        alias exclude_end? exclude_end
        alias exclude_start? exclude_start
        alias :end to

        def discrete_type?
          # Exclude :datetime, :timestamp, :decimal
          [:integer, :date].include? @subtype
        end

        # Check for equivalence in the discrete sense.
        # Note, this only checks for equivalence achieved from incrementing the exclusive lower
        # bound or decrementing the exclusive upper bound of this range. Invert the argument and
        # the receiving object to check the other possible equivalence situations. In most cases,
        # these two calls will be performed together. For example
        #
        #   a = PGRange.new(1, 10, :integer, :exclude_start => false, :exclude_end => false)
        #   b = PGRange.new(1, 11, :integer, :exclude_start => false, :exclude_end => true)
        #
        #   a.equivalent_discrete?(b) # => false
        #   b.equivalent_discrete?(a) # => true
        #
        #   # Complete check for discrete equivalence
        #   a.equivalent_discrete?(b) || b.equivalent_discrete?(a) # => true
        #
        def equivalent_discrete?(other)
          return false if !matches?(other, [:subtype, :unbound_start?, :unbound_end?])
          if discrete_type? && valid_ruby_range?
            if !unbound_start? && exclude_start? && !other.exclude_start?
              eq ||= matches?(other, [:from, :to], {:from => from.succ})
              eq ||= matches?(other, [:from, :to], {:from => from.succ, :to => last(1).first}) if !unbound_end? && exclude_end? && !other.exclude_end?
            elsif !unbound_end? && exclude_end? && !other.exclude_end?
              eq ||= matches?(other, [:from, :to], {:to => last(1).first})
            end
          end
          !!eq
        end

        def ==(other)
          if other.is_a? PGRange
            exactly_equals = matches?(other, [:from, :to, :subtype, :exclude_start, :exclude_end])
            exactly_equals || equivalent_discrete?(other) || other.equivalent_discrete?(self)
          else
            false
          end
        end
        alias eql? ==

        def ===(other)
          eql?(other) || (valid_ruby_range? && to_range === other)
        end

        def begin
          @from
        end

        def cover?(value)
          return false if empty?
          return false if value == self.begin && exclude_start?
          return false if value == self.end && exclude_end?
          begin
            if unbound_start?
              unbound_end? || value <= self.end
            else
              value >= self.begin && (unbound_end? || value <= self.end)
            end
          rescue ArgumentError # Compared uncomparable types
            false
          end
        end

        def empty?
          !unbound_start? && !unbound_end? && (@from > @to || @from == @to && (exclude_start? || exclude_end?))
        end

        def end
          @to
        end
        
        # Hacky way to dig out the values ourselves
        def first(n=1)
          raise(ArgumentError, "negative array size (or size too big)") if n < 0
          if empty?
            return n == 1 ? nil : []
          else
            return self.begin if n == 1
            raise(RuntimeError, "can't find first #{n} elements without lower bound") if unbound_start?
            raise(TypeError, "can't iterate from #{@subtype}") if !self.begin.respond_to?(:succ)
            val = self.exclude_start? ? self.begin : self.begin.succ
            values = []
            n.times do
              values << val
              val = val.succ
            end
            values
          end
        end

        def include?(value)
          return false if empty?
          to_range.include?(value)
        end
        alias member? include?

        # Crude
        def inspect
          "<PGRange:#{@subtype} #{to_s}>"
        end

        # Will handle a special case with no lower bound, but otherwise delegates.
        # Unlike min, we can't find the next value if the important end is excluded.
        def max
          return nil if empty?
          if unbound_start? && !unbound_end? && !exclude_start? 
            self.end
          else
            to_range.max
          end
        end

        # Will handle cases with lower bound and no upper bound. All other cases delegated.
        def min
          return nil if empty?
          if !unbound_start? && unbound_end?
            exclude_start? ? self.begin.succ : self.begin
          else
            to_range.min
          end
        end

        def size
          return 0 if empty?
          to_range.size
        end

        # Attempts to convert this PGRange to a ::Range for cases when only discrete values are used. Since
        # only discrete values are used, we can deal with exclusive lower bounds.
        def to_range
          if defined? @ruby_range
            @ruby_range
          else
            raise(RuntimeError, "can't discretize unbounded PGRange") if unbound_start? || unbound_end?
            raise(TypeError, "can't iterate from #{@subtype}") if !self.begin.respond_to?(:succ)
            start = self.exclude_start? ? self.begin.succ : self.begin
            @ruby_range = ::Range.new(start, self.end, self.exclude_end?)
          end
        end

        def to_s
          l_end = exclude_start? ? "(" : "["
          r_end = exclude_end? ? ")" : "]"
          "#{l_end}#{self.begin},#{self.end}#{r_end}"
        end

        def unbound_end?
          @to.nil?
        end

        def unbound_start?
          @from.nil?
        end

        def valid_ruby_range?
          !(empty? || exclude_start? || @from.nil? || @to.nil?)
        end

        def matches?(other, other_names, substitute_values={})
          other_names.all? do |name|
            value = substitute_values.include?(name) ? substitute_values[name] : self.public_send(name)
            value == other.public_send(name)
          end
        end
      end
    end
  end
end
