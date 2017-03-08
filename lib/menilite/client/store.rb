module Menilite
  class Store
    def initialize
      @tables = {}
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
      self[model_class][id]
    end

    def save(model)
      is_array = model.is_a?(Array)
      models = is_array ? model : [ model ]
      model_class = models.first.class
      table = @tables[model_class]
      Menilite::Http.post_json("api/#{model_class.to_s}", models.to_json) do
        on :success do |json|
          results = json.map do |value|
            if table.has_key?(value[:id])
              table[value[:id]].update(value)
              table[value[:id]]
            else
              table[value[:id]] = model_class.new(value)
            end
          end

          yield(is_array ? results : results.first) if block_given?
        end

        on :failure do |res|
          puts ">> Error: #{res.error}"
          puts ">>>> save: #{model.inspect}"
        end
      end
    end

    def fetch!(model_class, filter: nil, includes: nil, order: nil, &block)
      tables = @tables
      params = filter && (?? + filter.map {|k,v| "#{k}=#{v}" }.join(?&))
      params = (params ? params + ?& : ??) + "order=#{[order].flatten.join(?,)}" if order
      params = (params ? params + ?& : ??) + "includes=#{includes}" if includes
      Menilite::Http.get_json("api/#{model_class}#{params}") do
        on :success do |json|
          tables[model_class] = json.map {|value| [value[:id], Menilite::Deserializer.deserialize(model_class, value, includes)] }.to_h
          yield tables[model_class].values if block_given?
        end

        on :failure do |res|
          puts ">> Error: #{res.error}"
          puts ">>>> save: #{model.inspect}"
        end
      end
    end

    def delete(mdoel_class)
      @tables[model_class] = {}
    end

    def max!(model_class, field_name, &block)
      Menilite::Http.get_json("api/#{model_class}?order=#{field_name}") do
        on :success do |json|
          if json.last
            model = model_class.new(json.last)
            yield model.fields[field_name]
          end
        end
      end
    end
  end
end
