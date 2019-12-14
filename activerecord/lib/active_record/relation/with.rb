# frozen_string_literal: true

module ActiveRecord
  module With
    def with_values
      @values[:with] || []
    end

    def with_values=(values)
      raise ImmutableRelation if @loaded
      @values[:with] = values
    end

    def with(opts = :chain, *rest)
      if opts.blank?
        self
      else
        spawn.with!(opts, *rest)
      end
    end

    def with!(opts = :chain, *rest) # :nodoc:
      self.with_values += [opts] + rest
      self
    end
  end
end
