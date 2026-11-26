# frozen_string_literal: true

require "active_support/ractors"

module ActiveSupport
  # Delete this file when Date::DATE_FORMATS and Time::DATE_FORMATS are removed.
  module DeprecatedFormats # :nodoc:
    MUTATORS = %i[
      []= store delete delete_if keep_if reject! select! filter! merge! update
      clear replace shift compact! transform_keys! transform_values!
    ].freeze
    private_constant :MUTATORS

    # Only publish snapshots for the deprecated hash itself, not for its copies.
    def self.build(builtins, &publish)
      formats = builtins.dup
      MUTATORS.each do |method|
        formats.define_singleton_method(method) do |*args, **kwargs, &block|
          result = super(*args, **kwargs, &block)
          publish.call(DeprecatedFormats.shareable_copy(formats, builtins))
          result
        end
      end
      formats
    end

    def self.shareable_copy(formats, builtins)
      formats.each_with_object({}) do |(name, format), snapshot|
        next unless Ractors.shareable?(name)

        snapshot[name] = if Ractors.shareable?(format)
          format
        elsif format.is_a?(String)
          String.new(format).freeze
        else
          builtins[name]
        end
      end.freeze
    end
  end
end
