# frozen_string_literal: true

module ActiveRecord
  module Associations
    module SetThroughAssociationSourceTarget
      def set_through_association_source_target(record)
        through_reflection = self.reflection.active_record.reflections.values.find { |r|
          r.through_reflection && r.through_reflection.name == self.reflection.name
        }
        if through_reflection && !through_reflection.collection?
          through_target = record.send(through_reflection.source_reflection.name)
          if through_target
            target_name = through_reflection.name
            owner.send("#{target_name}=", through_target)
          end
        end
      end
    end
  end
end
