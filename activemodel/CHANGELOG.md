*   Allows configurable attribute name for `#has_secure_password`. This
    still defaults to an attribute named 'password', causing no breaking
    change. There is a new method `#authenticate_XXX` where XXX is the 
    configured attribute name, making the existing `#authenticate` now an
    alias for this when the attribute is the default 'password'. 
    Example:
    
        class User < ActiveRecord::Base
            has_secure_password :activation_token, validations: false
        end
        
        user = User.new()
        user.activation_token = "a_new_token"
        user.activation_token_digest                        # => "$2a$10$0Budk0Fi/k2CDm2PEwa3Be..."
        user.authenticate_activation_token('a_new_token')   # => user
        
     *Unathi Chonco*

*   Removed deprecated `:tokenizer` in the length validator.

    *Rafael Mendonça França*

*   Removed deprecated methods in `ActiveModel::Errors`.

    `#get`, `#set`, `[]=`, `add_on_empty` and `add_on_blank`.

    *Rafael Mendonça França*


Please check [5-0-stable](https://github.com/rails/rails/blob/5-0-stable/activemodel/CHANGELOG.md) for previous changes.
