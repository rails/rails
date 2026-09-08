# frozen_string_literal: true

module ActiveRecord
  module Associations
    class Preloader
      class Batch # :nodoc:
        def initialize(preloaders, available_records:)
          @preloaders = preloaders.reject(&:empty?)
          @available_records = available_records.flatten.group_by { |r| r.class.base_class }
        end

        def call
          branches = @preloaders.flat_map(&:branches)
          until branches.empty?
            loaders = branches.flat_map(&:runnable_loaders)

            loaders.each { |loader| loader.associate_records_from_unscoped(@available_records[loader.klass.base_class]) }

            if loaders.any?
              future_tables = branches.flat_map do |branch|
                branch.future_classes - branch.runnable_loaders.map(&:klass)
              end.map(&:table_name).uniq

              target_loaders = loaders.reject { |l| future_tables.include?(l.table_name)  }
              target_loaders = loaders if target_loaders.empty?

              group_and_load_similar(target_loaders)
              target_loaders.each(&:run)
            end

            finished, in_progress = branches.partition(&:done?)

            branches = in_progress + finished.flat_map(&:children)
          end
        end

        private
          attr_reader :loaders

          def group_and_load_similar(loaders)
            non_through = loaders.grep_v(ThroughAssociation)

            grouped = non_through.group_by do |loader|
              [loader.loader_query, loader.klass]
            end

            grouped.each do |(query, _klass), similar_loaders|
              query.load_records_in_batch(similar_loaders)
            end
          end
      end
    end
  end
end
