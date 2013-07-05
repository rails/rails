class Hash
  # Allows access to deeply nested hash items.
  #
  # The following lines are equivalent:
  #
  #     group_id = params[:user] && params[:user][:group] && params[:user][:group][:group_id]
  #     group_id = params.seek(:user, :group, :group_id)
  #
  # Like Hash#fetch, this method also takes an optional block, which will be
  # used to compute(but not assign!) the return value, if nil would otherwise be returned.
  #
  #     group_id = params.deep_fetch(:user, :group, :group_id) { Group.default_id }
  def seek(*args, &block)
    args.inject(self) do |new_hash, key|
      new_hash[key] or return (block && block.call(*args))
    end
  end
end
