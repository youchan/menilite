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
  class Model
    attr_reader :fields

    def initialize(fields = {})
      fields = fields.map{|k,v| [k.to_sym, v] }.to_h
      defaults = self.class.field_info.map{|k, d| [d.name, d.params[:default]] if d.params.has_key?(:default) }.compact.to_h
      @guid = fields.delete(:id) || SecureRandom.uuid
      @fields = defaults.merge(fields)
      @listeners = {}
    end

    def id
      @guid
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

    class << self
      def field_info
        @field_info ||= {}
      end

      def action_info
        @action_info ||= {}
      end

      def save(collection, &block)
        self.store.save(collection, &block)
      end

      def create(fields, &block)
        self.new(fields).save(&block)
      end

      def delete_all
        store.delete(self)
      end

      def fetch(filter: nil, order: nil)
        filter = filter.map{|k, v| type_convert(k, v)  }.to_h if filter
        store.fetch(self, filter: filter, order: order) do |list|
          yield list if block_given?
        end
      end

      def type_convert(key, value)
        converted = case field_info[key.to_s].type
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

      def inherited(child)
        store.register(child)
      end

      FieldInfo = Struct.new(:name, :type, :params)

      def field(name, type = :string, params = {})
        params.merge!(client: true, server: true)

        if RUBY_ENGINE == 'opal'
          return unless params[:client]
        else
          return unless params[:server]
        end

        field_info[name.to_s] = FieldInfo.new(name, type, params)

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

      ActionInfo = Struct.new(:name, :options)

      def action(name, params = {}, &block)
        action_info[name.to_s] = ActionInfo.new(name, params)
        if RUBY_ENGINE == 'opal'
          args = (block.parameters || []).map{|a| a[1] }.join(',')
          method = Proc.new do |model, *args| # todo: should adopt keyword parameters
            action_url = on_create ? "api/#{self}/#{name}" : "api/#{self}/#{model.id}/#{name}"
            post_data = {}
            post_data[:args] = (block.parameters || []).map{|a| [a[1], args.shift] }.to_h
            post_data[:model] = self.to_h if params[:on_create]
            Browser::HTTP.post(action_url, post_data.to_json) do
              on :success do |res|
                # todo: should callback user function
              end

              on :failure do |res|
                puts ">> Error: #{res.error}"
                puts ">>>> save: #{model.inspect}"
              end
            end
          end
          self.instance_eval "define_method(:#{name}) {#{args.empty? ? '' : '|' + args + '|'} method.call(self, #{args}) }"
        else
          self.instance_eval do
            define_method(name, block)
          end
        end
      end

      def [](id)
        store.find(self, id)
      end

      def max(field_name)
        store.max(self, field_name)
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

    def to_h
      @fields.merge(id: @guid)
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
