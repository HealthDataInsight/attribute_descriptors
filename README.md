What's this?
------------

This module let's you add syntactic sugar and helper methods on an
attribute basis. For example to create an input field in a form you can simply
use `User.forename.as_input_field`.

The way this works is by having a YAML that describes your data like below.

    First name:
      programmatic_name: firstname
      description: The forename of a person.
      valid_pattern: /\D*/
    Last name:
      programmatic_name: lastname
      valid_pattern: /\D*/

You can then access this data where it makes sense. For example `User.firstname` will
give you the metadata for the first name. Accessing from the instance is also possible
(e.g. `user.metadata`).

The benefit of all this is that you can encapsulate and re-use data descriptions
in classes. In conjunction with Rails some helper methods are also attached to
the classes bases on the metadata for creating forms and altering validations on
an attribute level.

Usage
-----

First you need to describe your data in a YAML file. Below we describe properties
of a user.

config/metadata/user.yml:

    Forename:
        programmatic_name: forename
        validate: \D*
        require: yes
    Surname:
        programmatic_name: surname
        validate: \D*
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
*`attr_descriptors`* - attaches the given metadata to the class
*`attributes`* - shows all attributes the model can take
*`required_attributes`* - shows all attributes that are marked as required

**Instance goodies**

*`attr_validations`* - let's you alter the behaviour of the validations. Takes `:only`, `:except`


Reserved keywords (describing your data)
--------------------

The keywords below are reserved for the helper methods when describing your data.
You are free add your own metadata entries as long as they don't collide with the ones below.

*`validate`* - regular expression being used to validate the field. The regular expression tries to match the WHOLE field. For example `\w*` is the same as `/\A\w*\z/` in pure Ruby.

*`programmatic_name`* - this is the name that will be used throughout the code
*`require`* - tells if this field is required when inserting new data
*`valid_values`* - list of permitted values for this data. If used in a form, this will
            generate a dropdown or selection input field.

*`valid_num_values`* - specifies how many values can be chosen. ie. 3 specifies excactly 3 values to be chosen, 3+ sets a minimum of 3, 2-5 sets a range between 2 and 5.
