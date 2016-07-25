require 'securerandom'

class String
  def camel_case
    return self if self !~ /_/ && self =~ /[A-Z]+.*/
    split('_').map{|e| e.capitalize}.join
  end
end

module Menilite
  class Model
    attr_reader :fields

    def initialize(fields)
      fields = fields.map{|k,v| [k.to_sym, v] }.to_h
      defaults = self.class.field_def.map{|k, d| [k, d.params[:default]] if d.params.has_key?(:default) }.compact.to_h
      @guid = fields.delete(:id) || SecureRandom.uuid
      @fields = defaults.merge(fields)
      @listeners = {}
    end

    def id
      @guid
    end

    def self.field_def
      @field_def ||= {}
    end

    def self.save(collection, &block)
      self.store.save(collection, &block)
    end

    def save(&block)
      self.class.store.save(self, &block)
    end

    def update(data)
      case data
      when self.class
        @fields.merge(data.fields)
      when Hash
        @fields.merge(data)
      when String
        @fields.merge(JSON.parse(json))
      end
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

    def self.create(fields, &block)
      self.new(fields).save(&block)
    end

    def self.delete_all
      store.delete(self)
    end

    def self.fetch(filter: nil, order: nil)
      filter = filter.map{|k, v| type_convert(k, v)  }.to_h if filter
      store.fetch(self, filter: filter, order: order) do |list|
        yield list if block_given?
      end
    end

    def self.type_convert(key, value)
      converted = case field_def[key.to_s].type
                  when :boolean
                    value.is_a?(String) ? (value == 'true' ? true : false) : value
                  else
                    value
                  end
      [key, converted]
    end

    def self.store
      Store.instance
    end

    def self.inherited(child)
      store.register(child)
    end

    FieldDef = Struct.new(:name, :type, :params)

    def self.field(name, type, params = {})
      field_def[name.to_s] = FieldDef.new(name, type, params)

      self.instance_eval do
        if type == :reference
          field_name = "#{name}_id"

          define_method(name) do
            id = @fields[field_name.to_sym]
            model_class = Object.const_get(name.camel_case)
            model_class[id]
          end

          define_method(name.to_s + "=") do |value|
            @fields[field_name.to_sym] = value.id
          end
        else
          field_name = name.to_s
        end

        define_method(field_name) do
          @fields[field_name.to_sym]
        end

        define_method(field_name + "=") do |value|
          unless type_validator(type).call(value, name)
            raise 'type error'
          end
          @fields[field_name.to_sym] = value
          handle_event(:change, field_name.to_sym, value)
        end
      end
    end

    def self.[](id)
      store.find(self, id)
    end

    def self.max(field_name)
      store.max(self, field_name)
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
          -> (value, name) { value.is_a? Date }
        when :reference
          -> (value, name) { valiedate_reference(value, name) }
      end
    end

    def valiedate_reference(value, name)
      return false unless value.is_a? String

      model_class = Object.const_get(name.camel_case)
      not model_class[value].nil?
    end

    def to_json(arg)
      @fields.merge(id: @guid).to_json
    end

    private

    def get_listeners(event, field_name)
      @listeners[event].try {|l1| l1[field_name] || [] } || []
    end

    def set_listener(event, field_name, &block)
      @listeners[event] ||= {}
      @listeners[event][field_name] ||= []
      @listeners[event][field_name] << block
    end
  end
end
