# frozen_string_literal: true

class Module
  # Triggers loading of all registered `autoload` on this module or class.
  def eager_load!
    constants.each do |const|
      const_get(const)
    end
    nil
  end
end
