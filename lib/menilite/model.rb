require 'securerandom'

if RUBY_ENGINE == 'opal'
  require 'browser/http'
  require 'opal-parser'
end

class String
  def camel_case
    return self if self !~ /_/ && self =~ /[A-Z]+.*/
    split('_').map{|e| e.capitalize}.join
  end
end

module Menilite
  class ValidationError < StandardError; end;
  class TypeError < StandardError; end;

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
        fields[:"#{name}_id"] = fields[info.name] if fields.has_key?(info.name)
      end

      fields.each{|k, v| validate(k, v) }
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

      def save(collection, &block)
        self.init
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

      def fetch(filter: {}, order: nil)
        self.init
        filter = filter.map{|k, v| type_convert(k.to_sym, v) }.to_h

        if_server do
          filter.merge!(privilege_filter)
        end

        store.fetch(self, filter: filter, order: order) do |list|
          yield list if block_given?
          list
        end
      end

      def type_convert(key, value)
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

      def store
        Store.instance
      end

      def subclasses
        @subclasses ||= {}
      end

      def inherited(child)
        subclasses[child] = false
      end

      FieldInfo = Struct.new(:name, :type, :params)

      def field(name, type = :string, params = {})
        params.merge!(client: true, server: true)

        if client?
          return unless params[:client]
        else
          return unless params[:server]
        end

        if type == :reference
          field_info[:"#{name}_id"] = FieldInfo.new(name, type, params)
        else
          field_info[name] = FieldInfo.new(name, type, params)
        end

        self.instance_eval do
          if type == :reference
            field_name = "#{name}_id"

            define_method(name) do
              id = @fields[field_name.to_sym]
              next nil unless id
              model_class = Object.const_get(name.to_s.camel_case)
              model_class[id]
            end

            define_method(name.to_s + "=") do |value|
              @fields[field_name.to_sym] = value.id
            end
          else
            field_name = name.to_s
          end

          define_method(field_name) do
            value = @fields[field_name.to_sym]
            if type.is_a?(Hash) && type.keys.first == :enum
              value = type[:enum][value]
            end
            value
          end

          define_method(field_name + "=") do |value|
            unless type_validator(type).call(value, name)
              raise ValidationError.new 'type error'
            end
            @fields[field_name.to_sym] = convert_value(type, value)
            handle_event(:change, field_name.to_sym, value)
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
            action_url = options[:on_create] || options[:class] ? "api/#{self}/#{name}" : "api/#{self}/#{model.id}/#{name}"
            post_data = {}
            post_data[:model] = model.to_h if options[:on_create]
            post_data[:args] = args
            Browser::HTTP.post(action_url, post_data.to_json) do
              on :success do |res|
                callback.call(:success, res) if callback
              end

              on :failure do |res|
                callback.call(:failure, res) if callback
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

      def find(id)
        self.init

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

      def max(field_name)
        self.init
        store.max(self, field_name)
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
    end

    def type_validator(type)
      case type
        when :string
          -> (value, name) { value.is_a? String }
        when :int
          -> (value, name) { value.is_a? Integer }
        when :boolean
          -> (value, name) { value == true || value == false }
        when :date
          -> (value, name) { value.is_a?(Date) || value.is_a?(String) }
        when :time
          -> (value, name) { value.is_a? Time }
        when Hash
          if type.keys.first == :enum
            -> (value, name) { value.is_a?(Integer) || type[:enum].include?(value) }
          else
            raise TypeError.new("type error")
          end
        when :reference
          -> (value, name) { validate_reference(value, name) }
        else
          raise TypeError.new("type error. type: #{type.inspect}")
      end
    end

    def validate_reference(value, name)
      return true if value.nil?
      return false unless value.is_a?(String) || value.is_a?(Menilite::Model)

      model_class = Object.const_get(name.to_s.camel_case)
      not model_class[value].nil?
    end

    def validate(name, value)
      field_info = self.class.field_info[name]
      raise ArgumentError.new("field '#{name}' is not defind") unless field_info
      validator = type_validator(field_info.type)
      raise TypeError.new("type error: field_name: #{field_info.name}, value: #{value}") unless validator.call(value, field_info.name)
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
  end
end
