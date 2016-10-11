*   Allows configurable attribute name for `#has_secure_password`. This
    still defaults to an attribute named 'password', causing no breaking
    change. Also includes a convenience method `#regenerate_XXX` where 
    +XXX+ is the name of the custom attribute name, eg:
    
        class User < ActiveRecord::Base
            has_secure_password :activation_token, validations: false
        end
        
        user = User.new()
        user.regenerate_activation_token
        user.activation_token               # => "ME7abXFGvzZWJRVrD6Et0YqAS6Pg2eDo"
        user.activation_token_digest        # => "$2a$10$0Budk0Fi/k2CDm2PEwa3Be..."
        
     The existing `#authenticate` method now allows specifying the attribute
     to be authenticated, but defaults to 'password', eg:
      
        user.authenticate('ME7abXFGvzZWJRVrD6Et0YqAS6Pg2eDo', :activation_token) # => user
        
     *Unathi Chonco*

*   Removed deprecated `:tokenizer` in the length validator.

    *Rafael Mendonça França*

*   Removed deprecated methods in `ActiveModel::Errors`.

    `#get`, `#set`, `[]=`, `add_on_empty` and `add_on_blank`.

    *Rafael Mendonça França*


Please check [5-0-stable](https://github.com/rails/rails/blob/5-0-stable/activemodel/CHANGELOG.md) for previous changes.
