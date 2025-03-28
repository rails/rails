# frozen_string_literal: true

module ActiveStorage
  class ClassResolver
    class << self
      def resolve(klass, type)
        db_config = ActiveStorage.database_configs.find { |config| config[:connection_class] == klass.connection_specification_name }

        # raise error if db_config is not found

        prefix = db_config[:connection_class] == "ActiveRecord::Base" ? nil : db_config[:name]

        "ActiveStorage::#{prefix.to_s&.camelize}#{type.to_s.classify}".constantize
      end
    end
  end
end
