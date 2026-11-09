# frozen_string_literal: true

module AbstractController
  module Config # :nodoc:
    class << self
      # Calling custom methods on the config instance goes through method_missing, which is slow.
      # Using config#[] is faster and call-caches can cache it.
      def generate_accessors(owner, *keys)
        keys.each do |key|
          methods = <<~RUBY
            def #{key}; config[#{key.inspect}]; end
            def #{key}=(value); config[#{key.inspect}] = value; end
          RUBY
          [owner, owner::ClassMethods].flatten.each do |owner|
            owner.class_eval(methods, __FILE__, __LINE__ - 4)
          end
        end
      end
    end
  end
end
