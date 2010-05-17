class String
  if defined?(Encoding) && "".respond_to?(:encode)
    def encoding_aware?
      true
    end
  else
    def encoding_aware?
      false
    end
  end
end