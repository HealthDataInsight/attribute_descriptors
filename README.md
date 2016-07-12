Usage
-----

Assuming you have a file containing the metadata for your model you can generate all attributes and validations for your model as seen below.

config/metadata/user.yml:

    Forename:
        validate: \D*
        require: yes


app/models/mymodel.rb:

    include metadata

    class User < Metadata::AutogeneratedModel
      generate_from 'config/metadata/user.yml'
    end


Then you can test it..

    user = User.new
    user.valid? # false
    user.errors # forename is blank

    attrs = {'forename' : 'john'}
    user = User.new(attrs)
    user.valid? # true

You can also access the metadata from the view, very handy to generate a form automatically.


Model extras
------------
Any model based on metadta, also inherits some extra methods as seen below.

attributes - shows all attributes the model can take
required_attributes - shows all attributes that are essential



Tests
-----

Install dependencies

    bundle

Run tests

    bundle exec rspec spec/metadata.rb    # common tests
    bundle exec rspec spec/validations.rb # test different validations


Metadata options
-------------------

The below options can be use to describe the data. Based on the options, the data
will be presented in a specific way when used for input (form), output and different
validation rules will be generated.

You can add your own metadata entries as long as they don't collide with the ones below.

*`validate`* - regular expression being used to validate the field. The regular expression tries to match the WHOLE field. For example `\w*` is the same as ``/\A\w*\z/` in pure Ruby.

*`programmatic_name`* - name for the data hat will be used everywhere in the code

*`require`* - tells if this field is required when inserting new data

*`values`* - list of permitted values for this data. If used in a form, this will
             generate a dropdown or selection input field.


Example (TODO)
-------

Assume we have this metadata for describing a user at *config/metadata/user.yml*:
```
First name:
  programmatic_name: firstname
  valid_pattern: \D*
Last name:
  programmatic_name: lastname
  valid_pattern: \D*
Age:
  programmatic_name: age
  input_instruction: Choose your age
  valid_range: 18-99
Occupation:
  programmatic_name: occupation
  input_instruction: Choose your occupation
  valid_num_values: 1
  valid_values:
    - Student
    - Employee
    - Employer
    - Other
Hobbies:
  programmatic_name: hobbies
  input_instruction: Choose 3 hobbies
  valid_num_values: 3+
  valid_values:
    - Music
    - Art
    - Sports
    - Reading
    - Other
```

First load the metadata in your model
```
include 'metadata'

class User
  generate_attributes_from_metadata 'config/metadata/user.yml'
  generate_validations_from_metadata 'config/metadata/user.yml'
  generate_form_helpers_from_metadata 'config/metadata/user.yml'
end
```

Then you can access many things at instance or class level
```
user = User.new({'name' => 'John'})
user.attributes          # -> { name => John }
user.required_attributes # -> {}
user.attribute_names     # -> [ name ]
user.attribute_values    # -> [ John ]


User.attribute_names     # -> [ name, lastname, age ]
User.name.as_form_field  # -> ..<input name="firstname" ..
User.age.as_form_field   # -> ..<select name="age" ..
```
