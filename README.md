What's this?
------------

The gem let's you describe data in a YAML file and generate forms and validations easily from that.


Assuming you have this metadata:

    First name:
      programmatic_name: firstname
      description: The forename of a person.
      valid_pattern: /\D*/
    Last name:
      programmatic_name: lastname
      valid_pattern: /\D*/

You can generate the needed HTML for a form with  `User.firstname.as_input_field` and validate directy with `User.new.valid?`.

The metadata for every model/class is always reachable, giving you the freedom to hack around, remove or build on top of it.



Usage
-----

First you need to describe your data in a YAML file. You are free to name the file whatever you want.

config/metadata/user.yml:

    Forename:
        programmatic_name: forename
        validate: \D*
        require: yes
    Surname:
        programmatic_name: surname
        validate: \D*
        require: yes  

Then you simply load the metadata to your model:

    include 'attribute_descriptors'

    class User
      include AttributeDescriptors
      attr_descriptors_from 'config/metadata/user.yml'
    end

You can then access the metadata or the helpers directly from the class.

    User.metadata

or

    User.forename

In the views you can access the form builders:

    User.forename.as_input_field


You can also generate validations.

    class User
      generate_validations
    end

    user = User.new
    user.valid? # false
    user.errors # forename is blank

    user = User.new
    user.forename = 'John'
    user.valid? # true


API
------------
Any model based on metadta, also inherits some extra methods as seen below.

**Class level**

*`attr_descriptors_form`* - attaches the metadata at the specific file location to the class
*`attr_descriptors`* - attaches the given metadata to the class
*`attributes`* - shows all attributes the model can take
*`required_attributes`* - shows all attributes that are essential

**Instance level**

*`attr_validations`* - let's you alter the behaviour of the validations. Takes `:only`, `:except`

**Metadata**

The below options can be use to describe the data. Based on the options, the data
will be presented in a specific way when used for input (form), output and different
validation rules will be generated.

You can add your own metadata entries as long as they don't collide with the ones below.

*`validate`* - regular expression being used to validate the field. The regular expression tries to match the WHOLE field. For example `\w*` is the same as ``/\A\w*\z/` in pure Ruby.

*`programmatic_name`* - name for the data hat will be used everywhere in the code

*`require`* - tells if this field is required when inserting new data

*`valid_values`* - list of permitted values for this data. If used in a form, this will
            generate a dropdown or selection input field.

*`valid_num_values`* - specifies how many values can be chosen. ie. 3 sets only 3 values, 3+ sets a minimum of 3, 2-5 sets a range between 2 and 5.
