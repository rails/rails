# frozen_string_literal: true

module ActiveRecord::Associations::Deprecation # :nodoc:
  # This is a code generator.
  #
  # Association builders use this method to generate code that guards
  # association access. This code is empty if the association is not deprecated
  # and it is not a through one.
  def self.generate_code_to_guard_deprecated_access(reflection)
    # For HABTMs, we check the deprecated flag in the parent association. This
    # is called from the internal has_many, the parent is the actual HABTM.
    if parent_reflection = reflection.options[:_habtm_reflection]
      reflection = parent_reflection
    end

    return unless reflection.deprecated? || reflection.through_reflection?

    source = +"_r = self.class.reflect_on_association(:#{reflection.name});"
    source << "#{name}.notify(_r);" if reflection.deprecated?
    source << "#{name}.guard_through_association(_r);" if reflection.through_reflection?
    source
  end

  def self.notify(reflection)
    # TODO
    # warn("The association #{reflection.active_record.name}##{reflection.name} is deprecated")
  end

  def self.guard_through_association(reflection)
    reflection.deprecated_nested_reflections.each { notify(_1) }
  end
end
