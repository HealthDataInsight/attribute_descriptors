require 'active_model'
require 'cgi'

# This module let's you describe attributes for a class in a YAML. The gem
# attaches the attributes' metadata to the class and generates view helpers
# for creating forms.
#
# Validations can also be created by using the generate_validations.
#
# ie. In a form you can use `User.username.as_input_field`
# ie. In a Rails controller you can use `@user.valid?`
#
# For more information you can contact the author at johan.seferidisf@phe.gov.uk
module AttributeDescriptors

  META_SPECIFIERS = [
    'require',
    'max_length',
    'min_length',
    'valid_values',
    'valid_num_values',
    'programmatic_name',
    'placeholder',
    'description' # This is the header for every attribute in the YAML
  ]

  # Set class-level and instance-level API methods
  def self.included base
    base.send :include, InstanceMethods
    base.extend ClassMethods
  end

  def self.load_file(filepath)
    f = open(filepath, 'r')
    file_content = f.read
    f.close
    load_yaml(file_content)
  end

  # Reads metadata from a raw YAML string
  def self.load_yaml(yaml)
    metadata = YAML.load(yaml)
    metadata.each do |attr_name, meta|

      # Generate a programmatic_name if none explicitly given
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

      # Check for possible misspells
      metadata[attr_name].each do |name, value|
        # TODO: Add Levenshtein distance or similar algorithm
        META_SPECIFIERS.each do |whitelisted|
          if (name.include?(whitelisted) || whitelisted.include?(name)) &&\
              whitelisted != name
            print("WARNING: AttributeDescriptors: did you mean '#{whitelisted}' in #{attr_name}?")
          end
        end
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
        when 'valid_values'
          parsed = {
            regexes: [],
            strings: []
          }
          values = value
          values.each do |value|
            if value.start_with?('/') && value.end_with?('/')
              re = value[1...-1]
              # Enforce the \A..\z regex placeholders for security reasons
              # (http://guides.rubyonrails.org/security.html#regular-expressions)
              re = re[1..-1]  if re.start_with?('^')
              re = re[0...-1] if re.start_with?('$')
              re = '\A' + re unless re.start_with?('\A')
              re += '\z' unless re.end_with?('\z')
              parsed[:regexes].push(Regexp.new(re))
            else
              parsed[:strings].push(value)
            end
          end
          metadata[attr_name][name] =  parsed

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




  class AttributesValidator < ActiveModel::Validator

    def validate_collection(collection, meta, attr_name, record)

      # Validate the number of values given
      range = meta['valid_num_values']
      case range
      when /\A\d*\-\d*\z/ # e.g. 2-5
        min, max = range.split('-').map{|n| n.to_i}
        if collection.size < min
          record.errors.add(attr_name, "too few values given")
        elsif collection.size > max
          record.errors.add(attr_name, "too many values given")
        end
      when /\A\d*\+\z/ # e.g. 5+
        min = range.to_i
        if collection.size < min
          record.errors.add(attr_name, "too few values given")
        end
      when /\A\d*\z/ # e.g. 5
        if collection.size < range.to_i
          record.errors.add(attr_name, "is less than number of allowerd values #{range.to_i}")
        elsif collection.size > range.to_i
          record.errors.add(attr_name, "exceeds number of allowed values #{range.to_i}")
        end
      else
        print("ERROR: Can't recognize given range '#{range}'")
      end

      # Validate each value separately
      collection.each do |value|
        validate_value(value, meta, attr_name, record)
      end

    end

    def validate_value(value, meta, attr_name, record)
      value = value.to_s

      # Limits of value
      if meta['min_length'] && meta['min_length'] > 0
        record.errors.add(attr_name, 'is too small') if value.size < meta['min_length']
      elsif meta['max_length'] && meta['max_length'] > 0
        record.errors.add(attr_name, 'is too big') if value.size > meta['max_length']

      # Inside permitted values
      elsif meta['valid_values']
        return if meta['valid_values'][:strings].include?(value)
        meta['valid_values'][:regexes].each do |regex|
          return if regex =~ value
        end
        record.errors.add(attr_name, 'is invalid')
      end

    end

    # There are two main cases:
    #  * collection (list)
    #  * single-value (numeric)
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
        if meta['require'] && (value.nil? || value.size < 1 ||
                               value == meta['placeholder'])
          record.errors.add(attr_name, 'is required')

        # Validate a collection
        elsif meta['valid_num_values'] && value.is_a?(Array)
          validate_collection(value, meta, attr_name, record)

        # Validate a single value
        else
          validate_value(value, meta, attr_name, record) if !value.nil? && value.size > 0
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
        html_value = prefill ? "value='#{CGI::escapeHTML(prefill)}'" : ''
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

    # Filter out (:except) attributes for validations or specify specific attributes (:only).
    def attr_validations(params = {})
      @attr_validations = params
    end

  end

  module ClassMethods

    # Access the attribute descriptors of the class
    def metadata
      class_variable_get(:@@metadata)
    end

    # Load metadata from file
    def attr_descriptors_from(filepath, params = {})
      metadata = AttributeDescriptors.load_file(filepath)
      attr_descriptors(metadata, params)
    end

    # Load metadata
    def attr_descriptors(metadata, params = {})
      include ActiveModel::Validations

      metadata = AttributeDescriptors.apply_metadata_filtering(metadata, params)

      # Attach the metadata to the class (not the module)
      class_variable_set(:@@metadata, metadata)

      generate_attr_accessors
      generate_attr_wrappers
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
      validates_with AttributesValidator
    end

    private

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
