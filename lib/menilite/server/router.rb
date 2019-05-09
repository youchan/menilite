require 'sinatra/base'
#require 'sinatra/json'
require 'json'

class Class
  def subclass_of?(klass, include_self = true)
    raise ArgumentError.new unless klass.is_a?(Module)

    if self == klass
      include_self
    else
      if self.superclass
        self.superclass.subclass_of?(klass)
      else
        false
      end
    end
  end
end

module Menilite
  class Router
    def initialize
      @classes = []

      ObjectSpace.each_object(Class) do |klass|
        @classes << klass if klass.subclass_of?(Menilite::Model, false)
        @classes << klass if klass.subclass_of?(Menilite::Controller, false)
        @classes << klass if klass.subclass_of?(Menilite::Privilege, false)
      end
    end

    def before_action_handlers(klass, action)
      @handlers ||= @classes.select{|c| c.subclass_of?(Menilite::Controller) }.map{|c| c.before_action_handlers }.flatten

      handlers = @handlers.select do |c|
        next true unless c[:options].has_key?(:include)
        [c[:options][:include]].flatten.any? do |includes|
          (classname, _, name) = includes.to_s.partition(?#)
          (classname == klass.name) && (name.empty? || name == action.to_s)
        end
      end

      handlers.reject do |c|
        [c[:options][:exclude]].flatten.any? do |exclude|
          (classname, _, name) = exclude.to_s.partition(?#)
          (classname == klass.name) && (name.empty? || name == action.to_s)
        end
      end
    end

    def routes(settings)
      classes = @classes
      router = self
      Sinatra.new do
        def with_error_handler(&block)
          block.call
        rescue Menilite::ErrorWithStatusCode => e
          content_type :json
          status e.code
          { result: 'error', message: e.message }.to_json
        rescue Menilite::ValidationError => e
          content_type :json
          status 403
          { result: 'validation_error', message: e.message, messages: e.messages }.to_json
        rescue => e
          puts e.message
          puts e.backtrace
          content_type :json
          status 500
          { result: 'error', message: e.message }.to_json
        end

        configure do
          enable :sessions
        end

        classes.each do |klass|
          case
          when klass.subclass_of?(Menilite::Model)
            klass.init
            resource_name = klass.name
            get "/#{resource_name}" do
              with_error_handler do
                PrivilegeService.init
                router.before_action_handlers(klass, 'index').each {|h| self.instance_eval(&h[:proc]) }
                order = params.delete('order')&.split(?,)
                includes = params.delete('includes')
                data = klass.fetch(filter: params, order: order, includes: includes)
                json Serializer.serialize(data, includes)
              end
            end

            get "/#{resource_name}/:id" do
              with_error_handler do
                PrivilegeService.init
                router.before_action_handlers(klass, 'get').each {|h| self.instance_eval(&h[:proc]) }
                includes = params.delete('includes')
                json Serializer.serialize(klass[params[:id]], includes)
              end
            end

            post "/#{resource_name}" do
              PrivilegeService.init
              router.before_action_handlers(klass, 'post').each {|h| self.instance_eval(&h[:proc]) }
              includes = params.delete('includes')
              data = JSON.parse(request.body.read)
              results = data.map do |model|
                instance = klass.new model.map{|key, value| [key.to_sym, value] }.to_h
                instance.save
                instance
              end

              json Serializer.serialize(results, includes)
            end

            delete "/#{resource_name}" do
              PrivilegeService.init
              router.before_action_handlers(klass, 'delete').each {|h| self.instance_eval(&h[:proc]) }
              params = JSON.parse(request.body.read)
              results = klass.fetch(filter: params).map do |model|
                model.delete
                model
              end

              json Serializer.serialize(results)
            end

            klass.action_info.each do |name, action|
              path = action.options[:save] || action.options[:class] ? "/#{resource_name}/#{action.name}" : "/#{resource_name}/#{action.name}/:id"

              post path do
                with_error_handler do
                  PrivilegeService.init
                  router.before_action_handlers(klass, action.name).each {|h| self.instance_eval(&h[:proc]) }
                  data = JSON.parse(request.body.read)
                  result = if action.options[:save]
                             klass.new(data["model"]).tap do |model|
                               model.send(action.name, *data["args"])
                               model.save
                             end
                           elsif action.options[:class]
                             klass.send(action.name, *data["args"])
                           else
                             klass[params[:id]].send(action.name, *data["args"])
                           end
                  if result.kind_of?(Menilite::Model)
                    json Serializer.serialize(result)
                  elsif result.is_a?(Array)
                    json result.map{|x| x.kind_of?(Menilite::Model) ? Serializer.serialize(x) : x }
                  else
                    json result
                  end
                end
              end
            end
          when klass.subclass_of?(Menilite::Controller)
            klass.action_info.each do |name, action|
              path = klass.respond_to?(:namespace) ? "/#{klass.namespace}/#{action.name}" : "/#{action.name}"
              post path do
                with_error_handler do
                  PrivilegeService.init
                  router.before_action_handlers(klass, action.name).each {|h| self.instance_eval(&h[:proc]) }
                  data = JSON.parse(request.body.read)
                  controller = klass.new(session, settings)
                  result = controller.send(action.name, *data["args"])
                  json result
                end
              end
            end
          end
        end
      end
    end
  end
end
