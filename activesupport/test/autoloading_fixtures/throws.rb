# frozen_string_literal: true

Throws = 1
_ = A::B # Autoloading recursion, expected to be discarded.

throw :t
