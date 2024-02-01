# frozen_string_literal: true

if defined?(ActiveRecord::Base)

  ActiveRecord::Migration.maintain_test_schema!

  if Rails.configuration.eager_load
    ActiveRecord::Base.descendants.each do |model|
      model.load_schema if !model.abstract_class? && model.table_exists?
    end
  end
end
