# frozen_string_literal: true

module ActiveRecord
  class FixtureSet
    class ClassCache
      def initialize(class_names, config)
        @class_names = class_names.stringify_keys
        @config      = config

        # Remove string values that aren't constants or subclasses of AR
        @class_names.delete_if do |klass_name, klass|
          !insert_class(@class_names, klass_name, klass)
        end
      end

      def [](fs_name)
        @class_names.fetch(fs_name) do
          klass = default_fixture_model(fs_name, @config).safe_constantize
          insert_class(@class_names, fs_name, klass)
        end
      end

      private

        def insert_class(class_names, name, klass)
          # We only want to deal with AR objects.
          if klass && klass < ActiveRecord::Base
            class_names[name] = klass
          else
            class_names[name] = nil
          end
        end

        def default_fixture_model(fs_name, config)
          ActiveRecord::FixtureSet.default_fixture_model_name(fs_name, config)
        end
    end
  end
end
