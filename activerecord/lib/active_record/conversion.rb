# frozen_string_literal: true

# :markup: markdown

require "active_record/errors"

module ActiveRecord
  module Conversion # :nodoc:
    # Returns self, wrapping errors in `ActiveRecord::Errors` so association
    # validation errors can be read from the corresponding foreign key
    # (for example `errors[:team_id]` after a presence error on `:team`).
    # A second call is a no-op.
    def to_model
      unless errors.is_a?(ActiveRecord::Errors)
        @errors = ActiveRecord::Errors.new(self, errors.objects, association_error_aliases)
      end

      self
    end

    private
      def association_error_aliases
        aliases = {}

        self.class.reflect_on_all_associations.each do |reflection|
          if reflection.belongs_to?
            Array(reflection.foreign_key).each do |foreign_key|
              next unless foreign_key
              aliases[foreign_key.to_sym] = reflection.name.to_sym
            end
            aliases[reflection.foreign_type.to_sym] = reflection.name.to_sym if reflection.polymorphic?
          elsif reflection.collection?
            aliases[:"#{reflection.name.to_s.singularize}_ids"] = reflection.name.to_sym
          end
        end

        aliases
      end
  end
end
