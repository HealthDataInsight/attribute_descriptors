Rename validation pattern keyword
------------------------------------
Rename `validate` to `valid_pattern` which suits more the declarative
nature of the YAML metadata file.

Allow multiple validations
-------------------------------------------------------------------------------
Reserve the keyword `valid_patterns` for allowing multiple valid regular expressions.

ie. valid_patterns:

      - [a-zA-Z]{1}\d{7}
      - [a-zA-Z]{2}\d{6}

Which validates for A1234567 and AB123456
