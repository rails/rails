require 'action_dispatch/journey/router'
require 'action_dispatch/journey/gtg/builder'
require 'action_dispatch/journey/gtg/simulator'
require 'action_dispatch/journey/nfa/builder'
require 'action_dispatch/journey/nfa/simulator'
# Journey is a router that uses a state machine to match HTTP requests to
# defined routes much like a computer language parses source code. Journey defines
# routes in a Generalized Transition Graph which is a nondeterministic finite
# state machine that allows moving from state to state by matching regular
# expressions.
# This is a fancy way of saying that instead of matching an incoming route to a
# long list of complete regular expressions representing each possible route it
# breaks the incoming request attributes into pieces and quickly narrows down
# the possible matching routes by following a map of possibilities (the GTG)
