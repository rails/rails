module ActiveSupport
  class TryProxy < BasicObject
    def initialize(object)
      @object = object
    end

    def method_missing(mid, *args, &bk)
      @object.public_send(mid, *args, &bk) if @object.respond_to?(mid)
    end

    class Nil < BasicObject
      def method_missing(*)
        nil
      end
    end
  end
end
