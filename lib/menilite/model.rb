require 'securerandom'
require_relative 'model/association'

if RUBY_ENGINE == 'opal'
  require 'opal-parser'
end

class String
  def camel_case
    return self if self !~ /_/ && self =~ /[A-Z]+.*/
    split('_').map{|e| e.capitalize}.join
  end
end

module Menilite
  class ValidationError < StandardError
    attr_reader :messages

    def initialize(messages)
      @messages = messages
      super(messages.join(', '))
    end
  end

  class TypeError < StandardError; end

  class Model
    include Menilite::Helper

    attr_reader :fields

    def initialize(fields = {})
      self.class.init

      if server?
        fields = fields.map{|k,v| [k.to_sym, v] }.to_h
      end

      @guid = fields.delete(:id) || SecureRandom.uuid

      self.class.field_info.select{|_, i| i.type == :reference}.each do |name, info|
        fields[name] = Association.new(info.params[:class])
        fields[name].load(fields["#{name}_id".to_sym]) if fields["#{name}_id".to_sym]
      end

      fields.each{|k, v| type_validate(k, v) }
      fields = fields.map{|k,v| [k, convert_value(self.class.field_info[k].type, v)] }.to_h
      if server?
        fields.merge!(self.class.privilege_fields)
      end

      defaults = self.class.field_info.map{|k, d| [d.name, d.params[:default]] if d.params.has_key?(:default) }.compact.to_h
      fields = defaults.merge(fields)
      @fields = defaults.merge(fields)
      @listeners = {}
    end

    def id
      @guid
    end

    def save(&block)
      self.validate_all
      self.class.store.save(self, &block)
      self
    end

    def update(data)
      case data
      when self.class
        @fields.merge!(data.fields)
      when Hash
        @fields.merge!(data.map{|k, v| resolve_references(k, v) }.to_h)
      when String
        @fields.merge!(JSON.parse(json))
      end
    end

    def update!(data, &block)
      self.update(data)
      self.save(&block)
    end

    def on(event, *field_names, &block)
      field_names.each {|file_name| set_listener(event, file_name, &block) }
    end

    def handle_event(event, field_name, value)
      get_listeners(event, field_name).each do |listener|
        listener.call(value)
      end
      value
    end

    class << self
      include Menilite::Helper

      def init
        if Model.subclasses.has_key?(self) && !Model.subclasses[self]
          store.register(self)
          Model.subclasses[self] = true
        end
      end

      def field_info
        @field_info ||= {}
      end

      def action_info
        @action_info ||= {}
      end

      def validators
        @validators ||= {}
      end

      def save(collection, &block)
        self.init
        collection.each {|obj| obj.validate_all }
        self.store.save(collection, &block)
      end

      def create(fields={}, &block)
        self.init
        self.new(fields).save(&block)
      end

      def delete_all
        self.init
        store.delete(self)
      end


      Menilite.if_server do
        def fetch(filter: {}, order: nil, includes: nil)
          self.init
          store.fetch(self, filter: convert_fileter(filter), order: order, includes: includes)
        end

        def max(field_name)
          self.init
          store.max(self, field_name)
        end
      end

      def find(id)
        case id
        when String
          self[id]
        when Hash
          self.fetch(filter:id).first
        end
      end

      def [](id)
        self.init
        store.find(self, id)
      end

      def fetch!(filter: {}, order: nil, includes: nil, &block)
        raise 'method is block required' unless block_given?

        self.init

        store.fetch!(self, filter: convert_fileter(filter), order: order, includes: includes) do |list|
          yield list
        end
      end

      def max!(field_name, &block)
        raise 'method is block required' unless block_given?

        self.init
        store.max!(self, field_name) do |max|
          yield max
        end
      end

      def store
        Store.instance
      end

      def subclasses
        @subclasses ||= {}
      end

      def inherited(child)
        subclasses[child] = false
      end

      def field(name, type = :string, params = {})
        params.merge!(client: true, server: true)

        if client?
          return unless params[:client]
        else
          return unless params[:server]
        end

        field_info[name] = FieldInfo.new(name, type, params)
        if type == :reference
          field_info["#{name}_id".to_sym] = FieldInfo.new("#{name}_id", :id, {})
        end

        self.instance_eval do
          if type == :reference
            define_method("#{name}_id") do
              @fields[name.to_sym].id
            end

            define_method("#{name}_id=") do |value|
              @fields[name.to_sym].load(value)
            end
          end

          define_method(name) do
            value = @fields[name.to_sym]
            if type.is_a?(Hash) && type.keys.first == :enum
              value = type[:enum][value]
            end
            value
          end

          define_method("#{name}=") do |value|
            puts "#{name}=#{value}: #{type}"
            unless type_validator(type).call(value, name)
              raise TypeError.new("type error: field name: #{name}, value: #{value}")
            end
            if type == :reference
              @fields[name.to_sym].assign convert_value(type, value)
            else
              @fields[name.to_sym] = convert_value(type, value)
            end
            handle_event(:change, name.to_sym, value)
          end
        end
      end

      ActionInfo = Struct.new(:name, :args, :options)

      def action(name, options = {}, &block)
        action_info[name.to_s] = ActionInfo.new(name, block.parameters, options)
        if server?
          self.instance_eval do
            if options[:class]
              define_singleton_method(name, block)
            else
              define_method(name, block)
            end
          end
        else
          method = Proc.new do |model, *args, &callback| # todo: should adopt keyword parameters
            action_url = options[:save] || options[:class] ? "api/#{self}/#{name}" : "api/#{self}/#{model.id}/#{name}"
            post_data = { args: args }

            if options[:save]
              begin
                model.validate_all
              rescue => e
                callback.call(:validation_error, e) if callback
                return
              end
              post_data[:model] = model.to_h
            end

            Menilite::Http.post_json(action_url, post_data.to_json) do
              on :success do |res|
                callback.call(:success, res) if callback
              end

              on :failure do |res|
                if callback
                  if res.json[:result] == 'validation_error'
                    callback.call(:validation_error, Menilite::ValidationError.new(res.json[:messages]))
                  else
                    callback.call(:failure, res)
                  end
                end
              end
            end
          end
          self.instance_eval do
            if options[:class]
              define_singleton_method(name) {|*args, &callback| method.call(self, *args, &callback) }
            else
              define_method(name) {|*args, &callback| method.call(self, *args, &callback) }
            end
          end
        end
      end

      def validation(field_name, params = {}, &block)
        params.each do |k, v|
          if validator = Validators[k, v]
            (validators[field_name] ||= []) << validator.new(self, field_name)
          end
        end
        (validators[field_name] ||= []) << Validator.new(self, field_name, &block) if block
      end

      def permit(privileges)
        Menilite.if_server do
          case privileges
          when Array
            self.privileges.push(*privileges)
          when Symbol, String
            self.privileges << privileges
          end
        end
      end

      Menilite.if_server do
        def privileges
          @privileges ||= []
        end

        def privilege_filter
          return {} unless PrivilegeService.current
          PrivilegeService.current.get_privileges(self.privileges).each_with_object({}) do |priv, filter|
            filter.merge!(priv.filter)
          end
        end

        def privilege_fields
          return {} unless PrivilegeService.current
          PrivilegeService.current.get_privileges(self.privileges).each_with_object({}) do |priv, fields|
            fields.merge!(priv.fields)
          end
        end
      end

      private

      def convert_fileter(filter)
        converted = filter.map{|k, v| convert_type(k.to_sym, v) }.to_h

        if_server do
          converted.merge!(privilege_filter)
        end

        converted
      end

      def convert_type(key, value)
        field_info = self.field_info[key] || self.field_info[key.to_s.sub(/_id\z/,'').to_sym]
        raise "no such field #{key} in #{self}" unless field_info
        converted = case field_info.type
                    when :boolean
                      value.is_a?(String) ? (value == 'true' ? true : false) : value
                    else
                      value
                    end
        [key, converted]
      end
    end

    def type_validator(type)
      case type
        when :string
          -> (value, name) { value.nil? || value.is_a?(String) }
        when :int
          -> (value, name) { value.nil? || value.is_a?(Integer) }
        when :boolean
          -> (value, name) { value.nil? || value == true || value == false }
        when :date
          -> (value, name) { value.nil? || value.is_a?(Date) || value.is_a?(String) }
        when :time
          -> (value, name) { value.nil? || value.is_a?(Time) }
        when Hash
          if type.keys.first == :enum
            -> (value, name) { value.nil? || value.is_a?(Integer) || type[:enum].include?(value) }
          else
            raise TypeError.new("type error")
          end
        when :reference
          -> (value, name) { client? || value.nil? || validate_reference(value, name) || value.is_a?(Association) }
        when :id
          -> (value, name) { value.nil? || value.is_a?(String) }
        else
          raise TypeError.new("type error. type: #{type.inspect}")
      end
    end

    def validate_reference(value, name)
      return false unless value.is_a?(String) || value.is_a?(Menilite::Model)

      model_class = Object.const_get(name.to_s.camel_case)
      not model_class[value].nil?
    end

    def type_validate(name, value)
      field_info = self.class.field_info[name]
      field_info or raise ArgumentError.new("field '#{name}' is not defind")

      type_validator = type_validator(field_info.type)
      type_validator.call(value, field_info.name) or raise TypeError.new("type error: field_name: #{field_info.name}, value: #{value}")
    end

    def validate(name, value)
      validators = self.class.validators[name]
      if validators
        messages = validators.select(&:enabled?).map {|validator| validator.validate(value) }.compact
      end
    end

    def validate_all
      messages = self.class.field_info.flat_map {|k, info| validate(k, self.fields[k]) }.compact
      messages.empty? or raise ValidationError.new(messages)
    end

    def [](key)
      if self.class.field_info.has_key?(key.to_sym) || self.class.field_info.has_key?("#{key}_id".to_sym)
        self.send(key)
      else
        raise ArgumentError.new("field '#{name}' is not defind")
      end
    end

    def to_h
      @fields.merge(id: @guid)
    end

    def to_json(arg)
      @fields.merge(id: @guid).to_json
    end

    private

    def convert_value(type, value)
      if type.is_a?(Hash) && type.keys.first == :enum
        if value.is_a?(Integer)
          value
        else
          type[:enum].index(value)
        end
      else
        value
      end
    end

    def get_listeners(event, field_name)
      @listeners[event].try {|l1| l1[field_name] || [] } || []
    end

    def set_listener(event, field_name, &block)
      @listeners[event] ||= {}
      @listeners[event][field_name] ||= []
      @listeners[event][field_name] << block
    end

    def resolve_references(key, value)
      if self.class.field_info.has_key?(key) && self.class.field_info[key].type == :reference
        ["#{key}_id".to_sym, value.id]
      else
        [key, value]
      end
    end

    class FieldInfo < Struct.new(:name, :type, :params)
      def default
        params[:default] if params.has_key?(:default)
      end
    end

    class Validator
      include Menilite::Helper

      def initialize(klass, name, &block)
        @class = klass
        @proc = block
      end

      def validate(value)
        @proc.call(value)
      end

      def enabled?
        if server?
          self.on_server
        else
          self.on_client
        end
      end

      def on_server
        true
      end

      def on_client
        true
      end
    end

    class PresenceValidator < Validator
      def initialize(klass, name)
        super(klass, name) {|value| "#{name} must not be empty" if value.nil? || value == "" }
      end
    end

    class UniqueValidator < Validator
      def initialize(klass, name)
        super(klass, name) do |value|
          "#{name}: '#{value}' already exist" unless klass.fetch(filter: { name => value }).empty?
        end
      end

      def on_client
        false
      end
    end

    class Validators
      def self.[](key, value)
        case key
        when :presence
          PresenceValidator if value == true
        when :unique
          UniqueValidator if value == true
        end
      end
    end
  end
end
