# frozen_string_literal: true

require 'active_support/concern'
require 'rails/generators/actions/create_migration'

module Rails
  module Generators
    # Holds common methods for migrations. It assumes that migrations have the
    # [0-9]*_name format and can be used by other frameworks (like Sequel)
    # just by implementing the next migration version method.
    module Migration
      extend ActiveSupport::Concern
      attr_reader :migration_number, :migration_file_name, :migration_class_name

      module ClassMethods #:nodoc:
        def migration_lookup_at(dirname)
          Dir.glob("#{dirname}/[0-9]*_*.rb")
        end

        def migration_exists?(dirname, file_name)
          migration_lookup_at(dirname).grep(/\d+_#{file_name}.rb$/).first
        end

        def current_migration_number(dirname)
          migration_lookup_at(dirname).collect do |file|
            File.basename(file).split('_').first.to_i
          end.max.to_i
        end

        def next_migration_number(dirname)
          raise NotImplementedError
        end
      end

      def create_migration(destination, data, config = {}, &block)
        action Rails::Generators::Actions::CreateMigration.new(self, destination, block || data.to_s, config)
      end

      def set_migration_assigns!(destination)
        destination = File.expand_path(destination, destination_root)

        migration_dir = File.dirname(destination)
        @migration_number     = self.class.next_migration_number(migration_dir)
        @migration_file_name  = File.basename(destination, '.rb')
        @migration_class_name = @migration_file_name.camelize
      end

      # Creates a migration template at the given destination. The difference
      # to the default template method is that the migration version is appended
      # to the destination file name.
      #
      # The migration version, migration file name, migration class name are
      # available as instance variables in the template to be rendered.
      #
      #   migration_template "migration.rb", "db/migrate/add_foo_to_bar.rb"
      def migration_template(source, destination, config = {})
        source = File.expand_path(find_in_source_paths(source.to_s))

        set_migration_assigns!(destination)
        context = instance_eval('binding')

        dir, base = File.split(destination)
        numbered_destination = File.join(dir, ['%migration_number%', base].join('_'))

        file = create_migration numbered_destination, nil, config do
          if ERB.instance_method(:initialize).parameters.assoc(:key) # Ruby 2.6+
            ERB.new(::File.binread(source), trim_mode: '-', eoutvar: '@output_buffer').result(context)
          else
            ERB.new(::File.binread(source), nil, '-', '@output_buffer').result(context)
          end
        end
        Rails::Generators.add_generated_file(file)
      end
    end
  end
end
