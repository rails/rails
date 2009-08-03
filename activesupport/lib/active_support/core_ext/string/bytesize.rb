unless '1.9'.respond_to?(:bytesize)
  class String
    alias :bytesize :size
  end
end
