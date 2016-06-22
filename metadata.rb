require 'active_model'

#
# This module let's you describe data in a YAML file and get a
# hash (aka dictionary) structure from it that can be used to automate a lot of
# things like form generation, data validators, etc.
#
# This is particularly useful when you want to generate a model and other components
# but without a database.
#
# Example
# -------
# Forename:
# Surname:
# NHS.net email address:
#   programmatic_name: nhsmail
#   validate: /.*@\.nhs\.net/
#
#
#    .. results in the metadata structure below..
#
# {
#   "Forename" => {
#      "require" => true,
#      "validate" => /.*/,
#      "min" => 0,
#      "max" => Infinity,
#      "values" => nil,
#      "max_num_values" => Infinity,
#      "min_num_values" => 0
#      "programmatic_name" => "forename"
#   },
#   "Surname" => {
#      "require" => true,
#      "validate" => /.*/,
#      "min" => 0,
#      "max" => Infinity,
#      "values" => nil,
#      "max_num_values" => Infinity,
#      "min_num_values" => 0
#      "programmatic_name" => "surname"
#   },
#   "NHS.net email address" => {
#      "validate" => "/.*@\\.nhs\\.net/",
#      "require" => true,
#      "min" => 0,
#      "max" => Infinity,
#      "values" => nil,
#      "max_num_values" => Infinity,
#      "min_num_values" => 0
#      "programmatic_name" => "nhsmail"
#   },
# }
#
module Metadata

  #
  # Reads a YAML configuration file specifying field names
  # and other meta data like minimum length, maximum length, etc.
  # and generates a structure that can be used in a view and/or model.
  #
  def self.load_file(filepath, defaults=nil)
    f = open(filepath, 'r')
    raw = f.read()
    f.close()
    return load_yaml(raw, defaults)
  end


  #
  # Reads raw YAML metadata specifying field names
  # and other meta data like minimum length, maximum length, etc.
  # and generates a structure that can be used in a view and/or model.
  #
  def self.load_yaml(yaml, defaults=nil)

    # IMPORTANT: Escape the escape backslashes before continuing
    #yaml = %q{yaml}

    metadata = YAML.load(yaml)

    # Expand any field directives (ie. 'require=yes' ) in place
    #
    # Example:
    #    numbers: a=10 b=20
    #        ..becomes..
    #    numbers => {
    #      'a' => 10,
    #      'b' => 20
    #    }
    #
    metadata.each do |fieldname, meta|

      #
      # Default values
      #
      # values     -> probable values of the field
      # values_max ->
      params = defaults || {
        'require'        => true,
        'validate'       => /.*/,
        'max_length'     => Float::INFINITY,
        'min_length'     => 0,
        'min_value'      => 0,
        'max_value'      => Float::INFINITY,
        'values'         => nil,
        'max_num_values' => nil,
        'min_num_values' => 0,
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
        metadata[fieldname] = {}
        asssignments.each do |assignment|
          k,v = assignment.split('=')
          metadata[fieldname][k] = v
        end
      end


      # Add any missing paramaters from defaults
      params.each do |k, v|
        metadata[fieldname][k] = params[k] if ! metadata[fieldname].include? k
      end


      # Generate a programmatic_name based on the fieldname if none explicitly given
      # IMPORTANT: Automatically generated programmatic names might be too long.
      #            You are advised to explicitly add the programmatic_name for
      #            each field in your metadata file.
      if metadata[fieldname]['programmatic_name'].nil?
        underscored = fieldname.tr(' !"#$%&\'()*+,-./:;<=>?@[\\]^_`{|}~', '_')
        singly_underscored = underscored.split('_').select{|v| ! v.empty? }.join('_')
        metadata[fieldname]['programmatic_name'] = singly_underscored
      end

      # Finally update/evaluate values to the ones given by configuration file
      metadata[fieldname].each do |name, value|
        case name
        when 'validate'
          if value.is_a?(String)
            value = value[1...-1] if value.start_with?('/') && value.end_with?('/')

            # Enforce the \A..\z regex placeholders for security reasons
            # (http://guides.rubyonrails.org/security.html#regular-expressions)
            value = value[1..-1]  if value.start_with?('^')
            value = value[0...-1] if value.start_with?('$')
            value = '\A'+value if ! value.start_with?('\A')
            value = value+'\z' if ! value.end_with?('\z')
          end
          metadata[fieldname][name] = Regexp.new(value)
        else
          metadata[fieldname][name] = value
        end
      end

    end

    return metadata
  end


  #
  # This class, once inherited let's you generate attributes and validations
  # based on metadata in a YAML file.
  #
  # Usage:
  #   1. Have your model inherit from AutogeneratedModel
  #   2. Use generated_from in your model to load metadata from a specific file
  #
  # attrs - the attributes you wish to populate
  #
  class AutogeneratedModel

    # Needed for the validations
    include ActiveModel::Validations

    #
    # (API) Access metadata
    #
    def metadata
      @@metadata || nil
    end


    #
    # (API) Load metadata and perform actions
    #
    # This runs on class level (aka before instance initialization)
    #
    def self.generated_from(filepath)
      @@metadata = Metadata.load_file(filepath)

      # Generate attribute accessors based on metadata
      programmatic_names = @@metadata.collect {|k_,v| v['programmatic_name']}
      programmatic_names.each do |name|
        class_eval { attr_accessor name }
      end

      # Generate validations based on metadata
      @@metadata.each do |field, meta|
        validates meta['programmatic_name'], :format      => meta['validate'],
                                             :allow_blank => !meta['require'],
                                             :presence    => meta['require'],
                                             :length      => meta['min_length']..meta['max_length']
      end
    end


    def initialize(attrs = {})

      if metadata.nil?
        raise "You need to call 'generated_from' in your class to specify the metadata path"
      end

      # Set attributes
      attrs.each do |name, value|
        self.send("#{name}=", value) if programmatic_names.include? name
      end

    end



    private

    def programmatic_names
      @@metadata.collect {|k_,v| v['programmatic_name']}
    end

  end


end
