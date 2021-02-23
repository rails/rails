# frozen_string_literal: true

module ActiveRecord
  module Associations
    class Preloader
      class Batch #:nodoc:
        def initialize(preloaders)
          @preloaders = preloaders.reject(&:empty?)
        end

        def call
          return if @preloaders.empty?

          branches = @preloaders.flat_map(&:branches)
          until branches.empty?
            loaders = branches.flat_map(&:loaders)
            group_and_load_similar(loaders)
            loaders.each(&:run)

            branches = branches.flat_map(&:children)
          end
        end

        private
          attr_reader :loaders

          def group_and_load_similar(loaders)
            loaders.grep_v(ThroughAssociation).group_by(&:grouping_key).each do |(_, _, association_key_name), similar_loaders|
              next if similar_loaders.all? { |l| l.already_loaded? }

              scope = similar_loaders.first.scope
              Association.load_records_in_batch(scope, association_key_name, similar_loaders)
            end
          end
      end
    end
  end
end
