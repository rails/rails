# frozen_string_literal: true

module ActiveRecord
  module Railties # :nodoc:
    module CollectionCacheAssociationLoading #:nodoc:
      def setup(context, options, as, block)
        @relation = nil

        return super unless options[:cached]

        @relation = relation_from_options(**options)

        super
      end

      def relation_from_options(cached: nil, partial: nil, collection: nil, **_)
        relation = partial if partial.is_a?(ActiveRecord::Relation)
        relation ||= collection if collection.is_a?(ActiveRecord::Relation)

        if relation && !relation.loaded?
          relation.skip_preloading!
        end
      end

      def collection_without_template(*)
        @relation.preload_associations(@collection) if @relation
        super
      end

      def collection_with_template(*)
        @relation.preload_associations(@collection) if @relation
        super
      end
    end
  end
end
