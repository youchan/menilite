require 'sinatra/activerecord'

module Menilite
  module ActiveRecord
    def self.create_model(model_class)
      klass = Class.new(::ActiveRecord::Base) do
        model_class.field_info.select{|name, field| field.type == :reference }.each do |name, field|
          belongs_to field.name, primary_key: 'guid', foreign_key: name + '_guid', class_name: name.capitalize
          #klass.instance_eval { define_method(name + '_id') { send(name + '_guid') } }
        end
      end
      self.const_set(model_class.to_s, klass)
    end
  end

  class Store
    def initialize
      @tables = {}
      @models = {}
    end

    def self.instance
      @instance ||= Menilite::Store.new
    end

    def register(model_class)
      @tables[model_class] = {}
      @models[model_class] = Menilite::ActiveRecord.create_model(model_class)
    end

    def find(model_class, id)
      m = @models[model_class].find_by(guid: id)
      model_class.new(fields(m, model_class))
    end

    def save(model)
      is_array = model.is_a?(Array)
      models = is_array ? model : [ model ]
      model_class = models.first.class

      models.each do |m|
        obj = find(model_class, m.id)
        if obj
          obj.update!(attributes(m))
        else
          @models[model_class].create!(attributes(m))
        end
      end

      yield model if block_given?
    end

    def fetch(model_class, filter: nil, order: nil)
      assoc = @models[model_class].all

      assoc = assoc.where(filter.entries.to_h) if filter
      assoc = assoc.order([order].flatten.map(&:to_sym)) if order

      yield assoc.map {|m| model_class.new(fields(m, model_class)) } || [] if block_given?
    end

    def delete(model_class)
      @models[model_class].delete_all
    end

    def max(model_class, field_name)
      fetch(model_class).max(field_name.to_sym)
    end

    private

    def [](model_class)
      @tables[model_class]
    end

    def attributes(model)
      references = model.class.field_info.values.select{|i| i.type == :reference}
      model.to_h.tap do |hash|
        references.each do |r|
          hash["#{r.name}_guid".to_sym] = hash.delete("#{r.name}_id".to_sym)
        end

        hash[:guid] = hash.delete(:id)
      end
    end

    def fields(ar_obj, model_class)
      references = model_class.field_info.values.select{|i| i.type == :reference}
      ar_obj.attributes.tap do |hash|
        references.each do |r|
          hash["#{r.name}_id"] = hash.delete("#{r.name}_guid")
        end
        hash["id"] = hash.delete("guid")
      end
    end
  end
end
