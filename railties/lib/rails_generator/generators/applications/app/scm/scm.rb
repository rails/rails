module Rails
  class Scm
    private
      def self.hash_to_parameters(hash)
        hash.collect { |key, value| "--#{key} #{(value.kind_of?(String) ? value : "")}"}.join(" ")
      end
  end
end