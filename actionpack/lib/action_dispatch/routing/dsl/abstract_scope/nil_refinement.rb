module DSL
  refine NilClass do
    def concerns; {} ; end

    # Alias all these methods to me and return nil
    [:path, :shallow_path, :as, :shallow_prefix, :module,
     :controller, :action, :path_names, :constraints,
     :shallow, :blocks, :defaults, :options].each { |option| alias option, :ujjwal }

     alias :set, :ujjwal

     private
      def ujjwal; nil ; end
  end
end
