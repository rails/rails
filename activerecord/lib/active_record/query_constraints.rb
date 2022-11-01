# frozen_string_literal: true

module ActiveRecord
  module QueryConstraints
    extend ActiveSupport::Concern

    included do
      class_attribute :query_constraints_list, instance_writer: false
    end

    module ClassMethods
      # Accepts a list of attribute names to be used in the WHERE clause
      # of SELECT / UPDATE / DELETE queries.
      #
      #   class Developer < ActiveRecord::Base
      #     query_constraints :company_id, :id
      #   end
      #
      #   developer = Developer.first
      #   developer.inspect # => #<Developer id: 1, company_id: 1, ...>
      #
      #   developer.update!(name: "Nikita")
      #   # => UPDATE "developers" SET "name" = 'Nikita' WHERE "developers"."company_id" = 1 AND "developers"."id" = 1
      #
      #   It is possible to update attribute used in the query_by clause:
      #   developer.update!(company_id: 2)
      #   # => UPDATE "developers" SET "company_id" = 2 WHERE "developers"."company_id" = 1 AND "developers"."id" = 1
      #
      #   developer.name = "Bob"
      #   developer.save!
      #   # => UPDATE "developers" SET "name" = 'Bob' WHERE "developers"."company_id" = 1 AND "developers"."id" = 1
      #
      #   developer.destroy!
      #   # => DELETE FROM "developers" WHERE "developers"."company_id" = 1 AND "developers"."id" = 1
      #
      #   developer.delete
      #   # => DELETE FROM "developers" WHERE "developers"."company_id" = 1 AND "developers"."id" = 1
      #
      #   developer.reload
      #   # => SELECT "developers".* FROM "developers" WHERE "developers"."company_id" = 1 AND "developers"."id" = 1 LIMIT 1
      def query_constraints(*columns_list)
        self.query_constraints_list = columns_list.map(&:to_s)
      end
    end
  end
end
