require 'active_support/concern'

module ActiveRecord
  module Scoping
    extend ActiveSupport::Concern

    included do
      include Default
      include Named
    end

    module ClassMethods
      # with_scope lets you apply options to inner block incrementally. It takes a hash and the keys must be
      # <tt>:find</tt> or <tt>:create</tt>. <tt>:find</tt> parameter is <tt>Relation</tt> while
      # <tt>:create</tt> parameters are an attributes hash.
      #
      #   class Article < ActiveRecord::Base
      #     def self.create_with_scope
      #       with_scope(:find => where(:blog_id => 1), :create => { :blog_id => 1 }) do
      #         find(1) # => SELECT * from articles WHERE blog_id = 1 AND id = 1
      #         a = create(1)
      #         a.blog_id # => 1
      #       end
      #     end
      #   end
      #
      # In nested scopings, all previous parameters are overwritten by the innermost rule, with the exception of
      # <tt>where</tt>, <tt>includes</tt>, and <tt>joins</tt> operations in <tt>Relation</tt>, which are merged.
      #
      # <tt>joins</tt> operations are uniqued so multiple scopes can join in the same table without table aliasing
      # problems. If you need to join multiple tables, but still want one of the tables to be uniqued, use the
      # array of strings format for your joins.
      #
      #   class Article < ActiveRecord::Base
      #     def self.find_with_scope
      #       with_scope(:find => where(:blog_id => 1).limit(1), :create => { :blog_id => 1 }) do
      #         with_scope(:find => limit(10)) do
      #           all # => SELECT * from articles WHERE blog_id = 1 LIMIT 10
      #         end
      #         with_scope(:find => where(:author_id => 3)) do
      #           all # => SELECT * from articles WHERE blog_id = 1 AND author_id = 3 LIMIT 1
      #         end
      #       end
      #     end
      #   end
      #
      # You can ignore any previous scopings by using the <tt>with_exclusive_scope</tt> method.
      #
      #   class Article < ActiveRecord::Base
      #     def self.find_with_exclusive_scope
      #       with_scope(:find => where(:blog_id => 1).limit(1)) do
      #         with_exclusive_scope(:find => limit(10)) do
      #           all # => SELECT * from articles LIMIT 10
      #         end
      #       end
      #     end
      #   end
      #
      # *Note*: the +:find+ scope also has effect on update and deletion methods, like +update_all+ and +delete_all+.
      def with_scope(scope = {}, action = :merge, &block)
        # If another Active Record class has been passed in, get its current scope
        scope = scope.current_scope if !scope.is_a?(Relation) && scope.respond_to?(:current_scope)

        previous_scope = self.current_scope

        if scope.is_a?(Hash)
          # Dup first and second level of hash (method and params).
          scope = scope.dup
          scope.each do |method, params|
            scope[method] = params.dup unless params == true
          end

          scope.assert_valid_keys([ :find, :create ])
          relation = construct_finder_arel(scope[:find] || {})
          relation.default_scoped = true unless action == :overwrite

          if previous_scope && previous_scope.create_with_value && scope[:create]
            scope_for_create = if action == :merge
              previous_scope.create_with_value.merge(scope[:create])
            else
              scope[:create]
            end

            relation = relation.create_with(scope_for_create)
          else
            scope_for_create = scope[:create]
            scope_for_create ||= previous_scope.create_with_value if previous_scope
            relation = relation.create_with(scope_for_create) if scope_for_create
          end

          scope = relation
        end

        scope = previous_scope.merge(scope) if previous_scope && action == :merge

        self.current_scope = scope
        begin
          yield
        ensure
          self.current_scope = previous_scope
        end
      end

      protected

      # Works like with_scope, but discards any nested properties.
      def with_exclusive_scope(method_scoping = {}, &block)
        if method_scoping.values.any? { |e| e.is_a?(ActiveRecord::Relation) }
          raise ArgumentError, <<-MSG
  New finder API can not be used with_exclusive_scope. You can either call unscoped to get an anonymous scope not bound to the default_scope:

  User.unscoped.where(:active => true)

  Or call unscoped with a block:

  User.unscoped do
  User.where(:active => true).all
  end

  MSG
        end
        with_scope(method_scoping, :overwrite, &block)
      end

      def current_scope #:nodoc:
        Thread.current["#{self}_current_scope"]
      end

      def current_scope=(scope) #:nodoc:
        Thread.current["#{self}_current_scope"] = scope
      end

      private

      def construct_finder_arel(options = {}, scope = nil)
        relation = options.is_a?(Hash) ? unscoped.apply_finder_options(options) : options
        relation = scope.merge(relation) if scope
        relation
      end

    end

    def populate_with_current_scope_attributes
      return unless self.class.scope_attributes?

      self.class.scope_attributes.each do |att,value|
        send("#{att}=", value) if respond_to?("#{att}=")
      end
    end

  end
end
