module ActionView
  module BodyParts
    class Future
      def to_s
        finish
        body
      end
    end
  end
end
