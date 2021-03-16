# frozen_string_literal: true

module ActiveRecord
  module Associations
    class Preloader
      class Batch #:nodoc:
        def initialize(preloaders)
          @preloaders = preloaders.reject(&:empty?)
        end

        def call
          branches = @preloaders.flat_map(&:branches)
          until branches.empty?
            loaders = branches.flat_map(&:runnable_loaders)

            already_loaded, loaders = loaders.partition(&:already_loaded?)
            already_loaded.each(&:run)

            group_and_load_similar(loaders)
            loaders.each(&:run)

            finished, in_progress = branches.partition(&:done?)

            branches = in_progress + finished.flat_map(&:children)
          end
        end

        private
          attr_reader :loaders

          def group_and_load_similar(loaders)
            loaders.grep_v(ThroughAssociation).group_by(&:loader_query).each_pair do |query, similar_loaders|
              query.load_records_in_batch(similar_loaders)
            end
          end
      end
    end
  end
end
