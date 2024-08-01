# frozen_string_literal: true

if defined?(ActiveRecord::Base)
  begin
    ActiveRecord::Migration.maintain_test_schema!
  rescue ActiveRecord::PendingMigrationError => e
    puts e.to_s.strip
    exit 1
  end

  if Rails.configuration.eager_load
    ActiveRecord::Base.descendants.each do |model|
      model.load_schema if !model.abstract_class? && model.table_exists?
    end
  end
end
