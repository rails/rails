class Hash
  def seek(*args)
    args.inject(self) do |new_hash, key|
      new_hash[key] or return nil
    end
  end
end
