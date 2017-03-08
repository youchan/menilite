module Menilite
  module Deserializer
    def self.deserialize(model_class, json, includes = nil)
      case json
      when Array
        json.map {|j| deserialize(model_class, j, includes) }
      when Hash
        if includes
          case includes
          when String
            assoc_data = json.delete(includes)
            assoc_id = json.delete(:id)
            obj = model_class.new(json)
            assoc = obj.send(includes).model_class.new(assoc_data)
            obj.send(includes + '=', assoc)
            obj
          when Array
            raise "not implemented"
          when Hash
            raise "not implemented"
          end
        else
          model_class.new(json)
        end
      end
    end
  end
end
