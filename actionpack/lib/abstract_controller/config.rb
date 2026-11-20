# frozen_string_literal: true

module AbstractController
  module Config # :nodoc:
    class << self
      # Calling custom methods on the config instance goes through method_missing, which is slow.
      # Using config#[] is faster and call-caches can cache it.
      def generate_accessors(owner, *keys)
        methods = []
        keys.each do |key|
          methods << "def #{key}; config[#{key.inspect}]; end"
          methods << "def #{key}=(value); config[#{key.inspect}] = value; end"
        end

        location = caller_locations(1, 1).first
        path = location&.path || __FILE__
        line = location&.lineno || __LINE__ - 6

        [owner, owner::ClassMethods].flatten.each do |owner|
          owner.class_eval(methods.join(";"), path, line)
        end
      end
    end
  end
end
