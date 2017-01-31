require "sdoc"

class RDoc::Generator::API < RDoc::Generator::SDoc # :nodoc:
  RDoc::RDoc.add_generator self

  def generate_class_tree_level(classes, visited = {})
    # Only process core extensions on the first visit.
    if visited.empty?
      core_exts, classes = classes.partition { |klass| core_extension?(klass) }

      super.unshift([ "Core extensions", "", "", build_core_ext_subtree(core_exts, visited) ])
    else
      super
    end
  end

  private
    def build_core_ext_subtree(classes, visited)
      classes.map do |klass|
        [ klass.name, klass.document_self_or_methods ? klass.path : "", "",
            generate_class_tree_level(klass.classes_and_modules, visited) ]
      end
    end

    def core_extension?(klass)
      klass.name != "ActiveSupport" && klass.in_files.any? { |file| file.absolute_name.include?("core_ext") }
    end
end
