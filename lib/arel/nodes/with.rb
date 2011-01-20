module Arel
	module Nodes
		class With < Arel::Nodes::Unary
			attr_reader :children
			alias value children
			alias expr  children

			def initialize *children
				@children = children
			end

		end

		class WithRecursive < With; end
	end
end

