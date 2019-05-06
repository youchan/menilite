require 'sinatra/activerecord'

module Menilite
  module ActiveRecord
    def self.create_model(model_class)
      klass = Class.new(::ActiveRecord::Base) do
        model_class.field_info.select{|name, field| field.type == :reference }.each do |name, field|
          belongs_to name, primary_key: 'guid', foreign_key: "#{name}_guid", class_name: name.to_s.capitalize
          #klass.instance_eval { define_method(name + '_id') { send(name + '_guid') } }
        end
      end
      self.const_set(model_class.to_s, klass)
    end
  end

  class Store
    def initialize
      @tables = {}
      @armodels = {}
    end

    def self.instance
      @instance ||= Menilite::Store.new
    end

    def register(model_class)
      @tables[model_class] = {}
      @armodels[model_class] = Menilite::ActiveRecord.create_model(model_class)
    end

    def armodel(model_class)
      @armodels[model_class]
    end

    def find(model_class, id)
      ar_obj = @armodels[model_class].find_by(guid: id)
      to_model(ar_obj, model_class) if ar_obj
    end

    def save(model)
      is_array = model.is_a?(Array)
      models = is_array ? model : [ model ]
      model_class = models.first.class

      models.each do |m|
        ar_obj = @armodels[model_class].find_by(guid: m.id)
        if ar_obj
          ar_obj.update!(attributes(m))
        else
          @armodels[model_class].create!(attributes(m))
        end
      end

      yield model if block_given?
    end

    def fetch(model_class, filter: nil, order: nil, includes: nil)
      assoc = @armodels[model_class].all

      assoc = assoc.where(filter_condition(model_class, filter)) if filter
      assoc = assoc.includes(includes) if includes
      assoc = assoc.order([order].flatten.map(&:to_sym)) if order

      assoc.map {|ar| to_model(ar, model_class) } || []
    end

    def delete(model_class, filter:)
      assoc = @armodels[model_class].all
      assoc = assoc.where(filter_condition(model_class, filter))
      res = assoc.map {|ar| to_model(ar, model_class) } || []
      assoc.delete_all
      res
    end

    def delete_all(model_class)
      @armodels[model_class].delete_all
    end

    def max(model_class, field_name)
      fetch(model_class).max(field_name.to_sym)
    end

    def to_model(ar_obj, model_class)
      model_class.new(fields(ar_obj, model_class))
    end

    private

    def [](model_class)
      @tables[model_class]
    end

    def filter_condition(model_class, filter)
      references = model_class.field_info.values.select{|i| i.type == :reference}
      filter.clone.tap do |hash|
        references.each do |r|
          hash["#{r.name}_guid".to_sym] = hash.delete("#{r.name}_id".to_sym) if hash.has_key?("#{r.name}_id".to_sym)
        end

        hash[:guid] = hash.delete(:id) if hash.has_key?(:id)
      end
    end

    def attributes(model)
      references = model.class.field_info.values.select{|i| i.type == :reference}
      model.to_h.tap do |hash|
        references.each do |r|
          hash["#{r.name}_guid".to_sym] = hash.delete("#{r.name}_id".to_sym)
          hash.delete(r.name.to_sym)
        end

        hash[:guid] = hash.delete(:id)
      end
    end

    def fields(ar_obj, model_class)
      references = model_class.field_info.values.select{|i| i.type == :reference }
      ar_obj.attributes.tap do |hash|
        references.each do |r|
          hash["#{r.name}_id"] = hash.delete("#{r.name}_guid")
        end
        hash["id"] = hash.delete("guid")
      end
    end
  end
end
