class Hash
  def seek(*args)
    if args.length == 1
      self[args.first]
    else
      self[args.first].try(:seek, *args[1..-1])
    end
  end
end
