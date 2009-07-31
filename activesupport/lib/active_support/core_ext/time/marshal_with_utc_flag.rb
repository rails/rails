# Pre-1.9 versions of Ruby have a bug with marshaling Time instances, where utc instances are
# unmarshalled in the local zone, instead of utc. We're layering behavior on the _dump and _load
# methods so that utc instances can be flagged on dump, and coerced back to utc on load.
if RUBY_VERSION < '1.9'
  class Time
    class << self
      alias_method :_original_load, :_load
      def _load(marshaled_time)
        time = _original_load(marshaled_time)
        utc = time.instance_variable_get('@marshal_with_utc_coercion')
        utc ? time.utc : time
      end
    end

    alias_method :_original_dump, :_dump
    def _dump(*args)
      obj = frozen? ? dup : self
      obj.instance_variable_set('@marshal_with_utc_coercion', utc?)
      obj._original_dump(*args)
    end
  end
end
