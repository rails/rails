# frozen_string_literal: true

module ActiveRecord
  module Railties # :nodoc:
    module CollectionCacheAssociationLoading #:nodoc:
      def render_collection_with_partial(collection, partial, context, block)
        @relation = nil

        return super unless @options[:cached]

        @relation = get_relation(collection)

        super
      end

      def get_relation(relation)
        if relation && relation.is_a?(ActiveRecord::Relation) && !relation.loaded?
          relation.skip_preloading!
          relation
        end
      end

      def relation_from_options(partial, collection)
        relation = partial if partial.is_a?(ActiveRecord::Relation)
        relation ||= collection if collection.is_a?(ActiveRecord::Relation)
        get_relation(relation)
      end

      def collection_with_template(_, _, _, collection)
        @relation.preload_associations(collection.collection) if @relation
        super
      end
    end
  end
end
