module ActionController #:nodoc:
  module Flash
    extend ActiveSupport::Concern

    included do
      class_attribute :_flash_types, instance_accessor: false
      self._flash_types = []

      delegate :flash, to: :request
      add_flash_types(:alert, :notice)
    end

    module ClassMethods
      def add_flash_types(*types)
        types.each do |type|
          next if _flash_types.include?(type)

          define_method(type) do
            request.flash[type]
          end
          helper_method type

          _flash_types << type
        end
      end
    end

    protected
      def redirect_to(options = {}, response_status_and_flash = {}) #:doc:
        self.class._flash_types.each do |flash_type|
          if type = response_status_and_flash.delete(flash_type)
            flash[flash_type] = type
          end
        end

        if other_flashes = response_status_and_flash.delete(:flash)
          flash.update(other_flashes)
        end

        super(options, response_status_and_flash)
      end
  end
end
