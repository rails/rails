# frozen_string_literal: true

if defined?(ActiveRecord::Base)
  begin
    ActiveRecord::Migration.maintain_test_schema!
  rescue ActiveRecord::PendingMigrationError => e
    puts e.to_s.strip
    exit 1
  end

  if Rails.configuration.eager_load
    rails_framework_base_classes = [ActionText::Record, ActiveStorage::Record, ActionMailbox::Record]

    ActiveRecord::Base.descendants.each do |model|
      next if rails_framework_base_classes.any? { |r| model < r } && !model.connection.table_exists?(model.table_name)

      model.load_schema unless model.abstract_class?
    end
  end
end
