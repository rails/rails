class Symbol

  # Unary ~ provides syntactic sugar for case statements. Examples:
  #
  #   case user
  #   when ~:admin?
  #     # Do stuff
  #   when ~:active?
  #     # Do stuff
  #   end
  #
  # Would be equivalent to:
  #
  #   if user.admin?
  #     # Do stuff
  #   elsif user.active?
  #     # Do stuff
  #   end
  alias_method :~, :to_proc
end
