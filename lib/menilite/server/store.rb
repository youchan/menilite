require 'json'

module Menilite
  class Store
    DEFAULT_DB_DIR = './.store'

    def initialize(db_dir = DEFAULT_DB_DIR)
      @tables = {}
      @db_dir = db_dir
      Dir.mkdir(@db_dir) unless Dir.exist?(@db_dir)
    end

    def self.instance
      @instance ||= Store.new
    end

    def register(model_class)
      @tables[model_class] = {}
    end

    def [](model_class)
      @tables[model_class]
    end

    def find(model_class, id)
      return self[model_class][id] if self[model_class][id]

      fetch(model_class)
      @tables[model_class][id]
    end

    def save(model)
      is_array = model.is_a?(Array)
      models = is_array ? model : [ model ]
      model_class = models.first.class

      models.each do |m|
        @tables[model_class][m.id] = m
      end

      File.open(filename(model_class), "w") do |file|
        file.write @tables[model_class].values.to_json
      end

      yield model if block_given?
    end

    def fetch(model_class, filter: nil, order: nil, includes: nil)
      File.open filename(model_class) do |file|
        records = JSON.parse(file.read)
        records.select! {|r| filter.all? {|k,v| r[k.to_s] == v } } if filter
        records.sort_by!{|r| [order].flatten.map{|o| r[o.to_s] } } if order
        @tables[model_class] = records.map {|m| [m["id"], model_class.new(m)] }.to_h
      end

      @tables[model_class].values || []
    end

    def fetch!(model_class, filter: nil, order: nil, includes: nil)
      yield fetch(model_class, filter, order, includes)
    end

    def delete(model_class)
      filename = self.filename(model_class)
      File.delete(filename) if File.exist?(filename)
    end

    def max(model_class, field_name)
      fetch(model_class)
      @tables[model_class].reduce(nil) {|v, max| v.fields[field_name] < max ? max : v.fields[field_name] }
    end

    def filename(model_class)
      @db_dir + "/#{model_class}.db"
    end
  end
end
