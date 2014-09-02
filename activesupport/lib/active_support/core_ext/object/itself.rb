class Object
  # TODO: Remove this file when we drop support for Ruby < 2.2
  unless respond_to?(:itself)
    # Returns the object itself.
    #
    # Useful for chaining methods, such as Active Record scopes:
    #
    #   Event.public_send(state.presence_in([ :trashed, :drafted ]) || :itself).order(:created_at)
    #
    # @return Object
    def itself
      self
    end
  end
end
