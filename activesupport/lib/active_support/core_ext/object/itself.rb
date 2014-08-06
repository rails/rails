class Object
  unless respond_to?(:itself) # TODO: Remove this file when we drop support for Ruby < 2.2
    # Returns the object itself. Useful when dealing with a chaining scenario, like Active Record scopes:
    #
    #   Event.public_send(state.presence_in([ :trashed, :drafted ]) || :itself).order(:created_at)
    #
    # @return Object
    def itself
      self
    end
  end
end
