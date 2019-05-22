module Menilite
  module Serializer
    def self.serialize(obj, includes=nil)
      case obj
      when Menilite::Model
        hash = obj.to_h
        if includes
          case includes
          when String, Symbol
            hash[includes.to_s] = obj[includes].to_h
          when Array
            includes.each do |i|
              hash[i.to_s] = obj[i].to_h
            end
          when Hash
            includes.each do |k, v|
              hash[k.to_s] = Menilite::Serializer.serialize(obj[k], v)
            end
          end
        end
        hash.delete_if{|k, v| v.is_a?(Menilite::Model::Association)}
      when Array
        obj.map {|o| Menilite::Serializer.serialize(o, includes) }
      end
    end
  end
end
