What's this?
------------

This module let's you add syntactic sugar and helper methods on an
attribute basis. For example to create an input field in a form you can simply
use `User.firstname.as_input_field` to generate the appropriate HTML.

The way this works is by having a YAML that describes your data like below.

    First name:
      programmatic_name: firstname
      description: The forename of a person.
      valid_values:
        - /\D*/
    Last name:
      programmatic_name: lastname
      valid_values:
        - /\D*/

You can then access this data where it makes sense. For example `User.firstname` will
give you all the metadata for that particular property. Accessing from the instance
is also possible (e.g. `user.metadata`).

The benefit of all this is that your classes become **data-driven**. In most MVC
frameworks like Rails you still have to duplicate validations between models
and forms. By adding one level of abstraction we have a single place that can be
used by any code constructs.


Usage
-----

First you need to describe your data in a YAML file. Below we describe properties
of a user.

config/metadata/user.yml:

    Forename:
        programmatic_name: forename
        valid_values:
          - /\D*/
        require: yes
    Surname:
        programmatic_name: surname
        valid_values:
          - /\D*/
        require: yes  

Then we use the metadata in our model:

    include 'attribute_descriptors'

    class User
      include AttributeDescriptors
      attr_descriptors_from 'config/metadata/user.yml'
    end

You can then access the metadata directly either from the class or an instance.

    User.forename     # gives metadata for forename
    User.new.metadata # gives the whole metadata

You also have access to helper methods that let you create form fields intuively.

    User.forename.as_input_field


You can also generate Rails validations automatically.

    include 'attribute_descriptors'

    class User
      include AttributeDescriptors
      attr_descriptors_from 'config/metadata/user.yml'
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
Below you can find methods and properties offered for classes and/or instances.

**Class goodies**

*`attr_descriptors_from`* - attaches the metadata at the specific file location to the class

*`attr_descriptors`* - attaches the given metadata to the class. Notice that this is *different* than the YAML structure

*`attributes`* - shows all attributes the model can take

*`required_attributes`* - shows all attributes that are marked as required

**Instance goodies**

*`attr_validations`* - let's you alter the behaviour of the validations. Takes `:only`, `:except`


Describing your data
--------------------

The keywords below are reserved for the helper methods when describing your data.
You are free add your own metadata entries as long as they don't collide with the ones below.

*`programmatic_name`* - this is the name that will be used throughout the code

*`description`* - description for the field

*`placeholder`* - text that is being shown in form fields

*`require`* - tells if this field is required when inserting new data

*`valid_values`* - list of permitted values for this data. REgular expressions are allowed
                   but they must start and end with '/'

*`valid_num_values`* - specifies how many values can be chosen. ie. 3 specifies excactly 3 values to be chosen, 3+ sets a minimum of 3, 2-5 sets a range between 2 and 5.

*`max_length`* - describes the maximum length of the value

*`min_length`* - describes the minimum length of the value
