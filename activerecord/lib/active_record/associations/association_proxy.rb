module ActiveRecord
  module Associations
    class AssociationProxy #:nodoc:
      alias_method :proxy_respond_to?, :respond_to?
      instance_methods.each { |m| undef_method m unless m =~ /(^__|^nil\?|^proxy_respond_to\?|^send)/ }

      def initialize(owner, association_name, association_class_name, association_class_primary_key_name, options)
        @owner = owner
        @options = options
        @association_name = association_name
        @association_class = eval(association_class_name)
        @association_class_primary_key_name = association_class_primary_key_name

        reset
      end
      
      def method_missing(symbol, *args, &block)
        load_target
        @target.send(symbol, *args, &block)
      end

      def respond_to?(symbol, include_priv = false)
        load_target
        proxy_respond_to?(symbol, include_priv) || @target.respond_to?(symbol, include_priv)
      end

      def loaded?
        @loaded
      end

      private
        def load_target
          unless @owner.new_record?
            begin
              @target = find_target if not loaded?
            rescue ActiveRecord::RecordNotFound
              reset
            end
          end
          @loaded = true
          @target
        end

        def raise_on_type_mismatch(record)
          raise ActiveRecord::AssociationTypeMismatch, "#{@association_class} expected, got #{record.class}" unless record.is_a?(@association_class)
        end
    end
  end
end
