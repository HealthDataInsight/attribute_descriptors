require 'active_model'
require 'awesome_print'

#
# This module let's you describe attributes for a class in a YAML. The gem
# attaches the attributes' metadata to the class and generates view helpers
# for creating forms.
#
# Validations can also be created by using the generate_validations.
#
# ie. In a form you can use `User.username.as_input_field`
# ie. In a Rails controller you can use `@user.valid?`
#
# For more information you can contact the author at manossef@gmail.com
#
module AttributeDescriptors

  INFINITY = Float::INFINITY

  # Set class-level and instance-level API methods
  def self.included base
    base.send :include, InstanceMethods
    base.extend ClassMethods
  end


  def self.load_file(filepath, defaults = nil)
    f = open(filepath, 'r')
    file_content = f.read
    f.close
    load_yaml(file_content, defaults)
  end

  # Reads raw YAML metadata specifying data name, length, max values, etc.
  def self.load_yaml(yaml, defaults = nil)
    metadata = YAML.load(yaml)

    metadata.each do |attr_name, meta|
      params = defaults || {
        'require'        => true,
        'validate'       => /.*/,
        'max_length'     => nil,
        'min_length'     => 0,
        'min_value'      => 0,
        'max_value'      => nil,
        'values'         => nil,
        'max_num_values' => nil,
        'min_num_values' => 0
      }

      # Expand compact syntax (ie. a=10 b=20)
      #
      # field1: require=true example=jojo
      #   validate: .*
      #
      #     ..gives the meta..
      # "field1" => "require=true example=jojo validate=.*"
      #
      if meta.is_a? String # This is always true if compact syntax is used
        asssignments = meta.split(' ')
        metadata[attr_name] = {}
        asssignments.each do |assignment|
          k, v = assignment.split('=')
          metadata[attr_name][k] = v
        end
      end

      # Add any missing paramaters from defaults
      params.each do |k, _v|
        metadata[attr_name][k] = params[k] unless metadata[attr_name].include? k
      end

      # Generate a programmatic_name based on the attr_name if none explicitly
      # given
      #
      # IMPORTANT: Automatically generated programmatic names might be too long.
      #            You are advised to explicitly add the programmatic_name for
      #            each field in your metadata file.
      if metadata[attr_name]['programmatic_name'].nil?
        underscored = attr_name.tr(' !"#$%&\'()*+,-./:;<=>?@[\\]^_`{ |}~', '_')
        singly_underscored = underscored.split('_').select { |v| !v.empty? }\
                                        .join('_')
        metadata[attr_name]['programmatic_name'] = singly_underscored
      end

      # Finally update/evaluate values to the ones given by configuration file
      metadata[attr_name].each do |name, value|
        case name
        when 'validate'
          if value.is_a?(String)
            value = value[1...-1] if value.start_with?('/') && \
                                     value.end_with?('/')

            # Enforce the \A..\z regex placeholders for security reasons
            # (http://guides.rubyonrails.org/security.html#regular-expressions)
            value = value[1..-1]  if value.start_with?('^')
            value = value[0...-1] if value.start_with?('$')
            value = '\A' + value unless value.start_with?('\A')
            value += '\z' unless value.end_with?('\z')
          end
          metadata[attr_name][name] = Regexp.new(value)
        when 'valid_num_values'
          metadata[attr_name][name] = value.to_s
        else
          metadata[attr_name][name] = value
        end
      end
    end

    # Swap attribute description with programmatic_name as key
    # since inside the code the programmatic_name makes it easier
    # to access speicfic attributes in the metadata.
    metadata_new = {}
    metadata.each do |attr_name, name|
      programmatic_name = metadata[attr_name]['programmatic_name']
      metadata_new[programmatic_name] = metadata[attr_name]
      metadata_new[programmatic_name]['description'] = attr_name
    end
    metadata = metadata_new

    metadata
  end

  # Filter metadata depending on parameters
  #
  # This is beneficial if you want to use a subset of the metadata for a given
  # class.
  def self.apply_metadata_filtering(metadata, params)
    metadata = metadata.dup

    # Filter out attributes
    if params.include? :except
      params[:except].each do |attr_name|
        metadata.delete(attr_name) || fail("'#{attr_name}' is not a valid attribute.")
      end
    end

    # Select specific attributes
    if params.include? :only
      metadata_new = {}
      params[:only].each do |attr_name|
        if metadata.include?(attr_name)
          metadata_new[attr_name] = metadata[attr_name]
        else
          fail("'#{attr_name}' is not a valid attribute.")
        end
      end
      metadata = metadata_new
    end

    metadata
  end


  class GenericValidator < ActiveModel::Validator
    def validate(record)
      metadata = record.class.class_variable_get(:@@metadata)

      # Due to Rails behaviour prior to 4.2, validations don't work if added
      # to the eigenclass of the instance. Therefore we let the user alter the
      # behaviour of the validations on an instance-basis by checking a specific
      # variable.
      validations_params = record.instance_variable_get(:@attr_validations)
      if validations_params
        metadata = AttributeDescriptors.apply_metadata_filtering(metadata, validations_params)
      end

      metadata.each do |attr_name, meta|
        value = record.send(attr_name)


        # Required
        if meta['require'] && (value.nil? || value.size < 1)
          record.errors.add(attr_name, 'is required')
        end

        if !value.nil? && value.size > 0

          # Regex validation
          if meta['validate'] && ! (meta['validate'] =~ value.to_s)
            record.errors.add(attr_name, 'is invalid')
          end

          # Length for collection
          if meta['valid_num_values']
            case meta['valid_num_values']
            # NOT SUPPORTED YET
            # when /\A\d*\-\d*\z/ # ie. 2-5
            #   min, max = range.split('-')
            #   length[:minimum] = min
            #   length[:maximum] = max
            # NOT SUPPORTED YET
            # when /\A\d*\+\z/ # ie. 5+
            #   length[:minimum] = range.to_i
            when /\A\d*\z/ # ie. 5
              #length[:minimum] = range.to_i
              #length[:maximum] = range.to_i

              # TODO (*): Make inclusion work for checking arrays. Rails only allows
              #       checking for membership of a single element.
              # Workaround for TODO *
              if !meta['valid_values'].include? value
                record.errors.add(attr_name, 'is invalid')
              end
            else
              print("ERROR: Can't recognize given range '#{range}'")
            end
          end

          # Limits of value
          if meta['min_length'] && meta['min_length'] > 0
            record.errors.add(attr_name, 'is too small') if value.size < meta['min_length']
          end
          if meta['max_length'] && meta['max_length'] > 0
            record.errors.add(attr_name, 'is too big') if value.size > meta['max_length']
          end

        end
      end
    end
  end




  # This class provides an interface to access all extras for every attribute.
  #
  # For example in User.firstname.as_input_field the User.firstname is an
  # instance of this class.
  class Attribute

    # Allow access to metadata with dot-notation
    def method_missing(meth, *args, &block)
      method_name = meth.to_s
      if @attr_meta && @attr_meta.include?(method_name)
        return @attr_meta[method_name]
      else
        super
      end
    end

    def initialize(attr_meta)
      @attr_meta = attr_meta
    end

    # Generates a form input field in HTML based on the metadata
    #
    # Looks for these values in metadata:
    #   * programmatic_name
    #   * placeholder
    #   * description
    #   * validate
    #   * valid_values
    def as_input_field(prefill = nil)
      attr_name = @attr_meta['programmatic_name']
      placeholder = @attr_meta['placeholder']
      attr_description = @attr_meta['description']

      html_label = "<label for='#{attr_name}'>#{attr_description}</label>"

      # Text field
      if @attr_meta['valid_values'].nil?
        html_placeholder = placeholder ? "placeholder='#{placeholder}'" : ''
        html_value = prefill ? "value='#{prefill}'" : ''
        html = "<input id='#{attr_name}' name='#{attr_name}' #{html_placeholder} type='text' #{html_value} />\n"

      # Dropdown
      else
        if placeholder
          instruction_option = [placeholder]
        else
          instruction_option = []
        end
        selection_options = instruction_option + @attr_meta["valid_values"]
        html = "<select id='#{attr_name}' name='#{attr_name}'>\n"
        selection_options.each do |option_value|
          html_selected = (option_value == prefill) ? ' selected' : ''
          html += "<option value='#{option_value}'#{html_selected}>#{option_value}</option>\n"
        end
        html += '</select>'

      end
      "#{html_label}\n#{html}\n"
    end

  end

  module InstanceMethods

    # (API) Further specifications for the validations.
    #
    # This method let's you filter out (:except) attributes for validations
    # or specify specific attributes (:only).
    def attr_validations(params = {})
      @attr_validations = params
    end

  end

  module ClassMethods

    # (API) Access the attribute descriptors of the class
    def metadata
      class_variable_get(:@@metadata)
    end

    #
    # (API) Load metadata from file
    #
    def attr_descriptors_from(filepath, params = {})
      metadata = AttributeDescriptors.load_file(filepath)
      attr_descriptors(metadata, params)
    end

    #
    # (API) Load metadata
    #
    def attr_descriptors(metadata, params = {})
      include ActiveModel::Validations

      metadata = AttributeDescriptors.apply_metadata_filtering(metadata, params)

      # Attach the metadata to the class (not the module)
      class_variable_set(:@@metadata, metadata)

      generate_attr_accessors
      generate_attr_wrappers
      # We don't generate validations automatically here in order to let the
      # user have more control over them.
    end

    # Gives back the attributes of the model
    def attributes
      metadata.keys
    end

    # Gives back the required attributes of the model
    def required_attributes
      metadata.select { |_k, meta| meta['require'] }.keys
    end

    # Redirects to the validator
    def generate_validations
      validates_with GenericValidator
    end

    # Generates attribute accessors for the class
    def generate_attr_accessors
      metadata.keys.each do |attr_name|
        attr_accessor attr_name
      end
    end

    # Attaches an Attribute object to the class for every attribute
    # in order to allow further functionality like view helpers, etc.
    #
    # Example:
    #   User.name # points to <Attribute: @@metadata={..}>
    def generate_attr_wrappers
      class << self
        metadata = class_variable_get(:@@metadata)
        metadata.each do |attr_name, meta|
          define_method(attr_name) do
            Attribute.new(meta)
          end
        end
      end
    end

  end

end
