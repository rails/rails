# frozen_string_literal: true

module ActiveRecord::Associations::Deprecation # :nodoc:
  class << self
    # This is a code generator.
    #
    # Association builders use this method to generate code that guards
    # association access. If the association is not deprecated and it is not a
    # through one this returns nil.
    def generate_code_to_guard_deprecated_access(reflection)
      # For HABTMs, the generator is called by the builder that defines an
      # internal has_many, but what matters is the HABTM itself.
      if habtm_reflection = reflection.options[:_habtm_reflection]
        reflection = habtm_reflection
      end

      return unless reflection.deprecated? || reflection.through_reflection?

      # We fetch the reflection via the association to make sure it passed
      # validation.
      #
      # Usage of a tap + numbered parameter avoids injecting a variable into the
      # enclosing source code.
      #
      # Example:
      #
      #   association(:comments).reflection.tap {
      #     ActiveRecord::Associations::Deprecation.notify(_1);
      #     ActiveRecord::Associations::Deprecation.guard_through_association(_1);
      #   }
      #
      # except we put it all in one line.
      source = +"association(:#{reflection.name}).reflection.tap { "
      source << "#{self}.notify(_1);" if reflection.deprecated?
      source << "#{self}.guard_through_association(_1);" if reflection.through_reflection?
      source << " }"
      source
    end

    def notify(reflection)
      # TODO
      # warn("The association #{reflection.active_record.name}##{reflection.name} is deprecated")
    end

    def guard_through_association(reflection)
      reflection.deprecated_nested_reflections.each { notify(_1) }
    end
  end
end
