module Menilite
  class Model
    class UnacquiredDataAccess < StandardError; end

    class Association
      attr_reader :model_class

      def initialize(model_class)
        @model_class = model_class
        @model = nil
      end

      def assign(model)
        @model = model
      end

      def load(id)
        assign @model_class.find(id)
      end

      def id
        @model && @model.id
      end

      def to_h
        raise UnacquiredDataAccess.new unless @model
        @model.to_h
      end

      private

      def method_missing(method_sym, *args, &block)
        field_name = method_sym.to_s
        field_name = field_name[0, field_name.size - 1] if field_name.chars.last == '='
        field = @model_class.field_info[field_name]
        if field
          raise UnacquiredDataAccess.new unless @model
          @model.send(method_sym, *args)
        else
          super
        end
      end
    end
  end
end
