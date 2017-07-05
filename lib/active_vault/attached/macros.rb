module ActiveVault::Attached::Macros
  def has_one_attached(name, dependent: :purge_later)
    define_method(name) do
      instance_variable_get("@active_vault_attached_#{name}") || 
        instance_variable_set("@active_vault_attached_#{name}", ActiveVault::Attached::One.new(name, self))
    end

    if dependent == :purge_later
      before_destroy { public_send(name).purge_later }
    end
  end

  def has_many_attached(name, dependent: :purge_later)
    define_method(name) do
      instance_variable_get("@active_vault_attached_#{name}") || 
        instance_variable_set("@active_vault_attached_#{name}", ActiveVault::Attached::Many.new(name, self))
    end

    if dependent == :purge_later
      before_destroy { public_send(name).purge_later }
    end
  end
end
