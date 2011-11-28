module ActionDispatch
  module Encoder

    # Beware that it modifies the parameter
    def self.encode_to_internal(str)
      str.force_encoding(Encoding::UTF_8)
      if !str.valid_encoding?
        replace_invalid_characters(str)
      end
      str.encode!
    end

    def self.replace_invalid_characters(str)
      for i in (0...str.size)
        if !str[i].valid_encoding?
          str[i] = "?"
        end
      end
    end
  end
end
