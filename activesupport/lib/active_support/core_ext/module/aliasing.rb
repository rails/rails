class Module
  # Encapsulates the common pattern of:
  #
  #   alias_method :foo_without_feature, :foo
  #   alias_method :foo, :foo_with_feature
  #
  # With this, you simply do:
  #
  #   alias_method_chain :foo, :feature
  #
  # And both aliases are set up for you.
  #
  # A punctuation is moved to the end on predicates or bang methods.
  #
  #   alias_method_chain :foo?, :feature
  # 
  # generates "foo_without_feature?" method for old one,
  # and expects "foo_with_feature?" method for new one.
  def alias_method_chain(target, feature)
    punctuation    = target.to_s.scan(/[?!]/).first
    aliased_target = target.to_s.sub(/[?!]/, '')
    alias_method "#{aliased_target}_without_#{feature}#{punctuation}", target
    alias_method target, "#{aliased_target}_with_#{feature}#{punctuation}"
  end
end
