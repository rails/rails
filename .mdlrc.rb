# frozen_string_literal: true

all

exclude_rule "MD003"
exclude_rule "MD004"
exclude_rule "MD005"
exclude_rule "MD006"
exclude_rule "MD007"
exclude_rule "MD012"
exclude_rule "MD014"
exclude_rule "MD024"
exclude_rule "MD026"
exclude_rule "MD032"
exclude_rule "MD033"
exclude_rule "MD034"
exclude_rule "MD036"
exclude_rule "MD040"
exclude_rule "MD041"

rule "MD013", line_length: 2000, ignore_code_blocks: true
# rule "MD024", allow_different_nesting: true # This did not work as intended, see action_cable_overview.md
rule "MD029", style: :ordered
# rule "MD046", style: :consistent # default (:fenced)
