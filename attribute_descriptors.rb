#
# This module let's you describe data in a YAML file to generate attribute
# view and validation helpers accessible at the class level.
#
# ie. In a form you can use `User.username.as_input_field`
# ie. In a Rails controller you can use `@user.valid?`
#
# For more information you can contact the author at manossef@gmail.com
#
module AttributeDescriptors

  INFINITY = Float::INFINITY

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



  # This class provides an interface to access all extras for every attribute.
  #
  # For example in User.firstname.as_input_field the User.firstname is an
  # instance of this class.
  #
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
      @attr_meta   = attr_meta
    end

    # Generates a form input field in HTML based on the metadata
    #
    # Looks for these values in metadata:
    #   * programmatic_name
    #   * placeholder
    #   * description
    #   * valid_pattern
    #   * valid_values
    #
    def as_input_field(prefill=nil)
      attr_name   = @attr_meta['programmatic_name']
      placeholder = @attr_meta['placeholder']
      attr_description = @attr_meta['description']

      html_label = "<label for='#{attr_name}'>#{attr_description}</label>"

      # Text field
      if @attr_meta["valid_values"].nil?
        html_placeholder = placeholder ? "placeholder='#{placeholder}'" : ''
        html_value       = prefill ? "value='#{prefill}'" : ''
        html = "<input id='#{attr_name}' name='#{attr_name}' #{html_placeholder} type='text' #{html_value} />\n"

      # Dropdown
      else
        if placeholder
          instruction_option = [ placeholder ]
        else
          instruction_option = []
        end
        selection_options = instruction_option + @attr_meta["valid_values"]
        html = "<select id='#{attr_name}' name='#{attr_name}'>\n"
        selection_options.each do |option_value|
          html_selected = (option_value == prefill) ? " selected" : ''
          html += "<option value='#{option_value}'#{html_selected}>#{option_value}</option>\n"
        end
        html += "</select>"

      end
      return "#{html_label}\n#{html}\n"
    end

  end



  #
  # (API)
  #
  # This class can be extended from a class in order to attach metadata
  # for the attributes for that class. You can afterwards access the metadata
  # directly or use the extra functionality provided like form views and
  # validations.
  #
  module ClassAttributes

    #
    # (API) Access the attribute descriptors of the class
    #
    def metadata
      class_variable_get(:@@metadata)
    end

    #
    # (API) Load metadata from file
    #
    def attr_descriptors_from(filepath, params={})
      metadata = AttributeDescriptors.load_file(filepath)
      attr_descriptors(metadata, params)
    end

    #
    # (API) Load metadata
    #
    def attr_descriptors(metadata, params={})

      metadata = apply_metadata_filtering(metadata, params)

      # Attach the metadata to the class (not the module)
      class_variable_set(:@@metadata, metadata)

      # Include Rails models
      require 'active_model'
      include ActiveModel::Validations

      generate_attr_accessors
      generate_attr_wrappers
      # We don't generate validations automatically here in order to let the user
      # have more control over them.
    end

    # Gives back the attributes of the model
    def attributes
      metadata.keys
    end

    # Gives back the required attributes of the model
    def required_attributes
      metadata.select { |_k, meta| meta['require'] }.keys
    end

    # Due to Rails behaviour prior to 4.2, validations don't work if added
    # to the eigenclass of the instance. Therefore we need other workarounds
    # if we wish to set different validations on an instance basis.
    def generate_validations

      metadata.each do |attr_name, meta|
        length = {}
        validation_params = {}

        # Length for single item
        length[:minimum] = meta['min_length'] if meta['min_length'] && \
                                                 meta['min_length'] > 0
        length[:maximum] = meta['max_length'] if meta['max_length'] && \
                                                 meta['max_length'] != INFINITY

        # Length for collection
        if meta['valid_num_values']
          range = meta['valid_num_values']
          case range
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

            # Workaround for TODO *
            validation_params[:inclusion] = meta['valid_values'] if meta['valid_values']
          else
            print("ERROR: Can't recognize given range '#{range}'")
          end
        end

        validation_params[:presence]    = true if meta['require']
        validation_params[:allow_blank] = !meta['require']
        validation_params[:format]      = meta['validate']
        validation_params[:length]      = length if !length.empty?
        # TODO (*): Make inclusion work for checking arrays. Rails only allows
        #       checking for membership of a single element.
        # Workaround line : ~235

        validates attr_name, validation_params
      end
    end


    # NOTICE: This is for the instances in contrast to the attr wrappers
    #         which are at the class level.
    def generate_attr_accessors
      metadata.keys.each do |attr_name|
        attr_accessor attr_name
      end
    end

    # Attach an Attribute object to the class for every attribute
    # in order to allow further functionality like view helpers, etc.
    #
    # For example you can have User.name points to <Attribute: @@metadata={..}>
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

    # Filter metadata depending on parameters
    def apply_metadata_filtering(metadata, params)
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


  end

end
