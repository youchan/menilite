require 'sinatra/base'
require 'sinatra/json'
require 'json'

class Class
  def subclass_of?(klass)
    raise ArgumentError.new unless klass.is_a?(Class)

    if self == klass
      true
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
    def initialize(*classes)
      @classes = classes
    end

    def before_action_handlers(klass, action)
      @handlers ||= @classes.select{|c| c.subclass_of?(Menilite::Controller) }.map{|c| c.before_action_handlers }.flatten
      @handlers.reject do |c|
        [c[:options][:expect]].flatten.any? do |expect|
          (classname, _, name) = expect.to_s.partition(?#)
          (classname == klass.name) && (name.empty? || name == action.to_s)
        end
      end
    end

    def routes(settings)
      classes = @classes
      router = self
      Sinatra.new do
        enable :sessions

        classes.each do |klass|
          case
          when klass.subclass_of?(Menilite::Model)
            klass.init
            resource_name = klass.name
            get "/#{resource_name}" do
              router.before_action_handlers(klass, 'index').each {|h| self.instance_eval(&h[:proc]) }
              order = params.delete('order')&.split(?,)
              data = klass.fetch(filter: params, order: order)
              json data.map(&:to_h)
            end

            get "/#{resource_name}/:id" do
              router.before_action_handlers(klass, 'get').each {|h| self.instance_eval(&h[:proc]) }
              json klass[params[:id]].to_h
            end

            post "/#{resource_name}" do
              router.before_action_handlers(klass, 'post').each {|h| self.instance_eval(&h[:proc]) }
              data = JSON.parse(request.body.read)
              results = data.map do |model|
                instance = klass.new model.map{|key, value| [key.to_sym, value] }.to_h
                instance.save
                instance
              end

              json results.map(&:to_h)
            end

            klass.action_info.each do |name, action|
              path = action.options[:on_create] || action.options[:class] ? "/#{resource_name}/#{action.name}" : "/#{resource_name}/#{action.name}/:id"

              post path do
                router.before_action_handlers(klass, action.name).each {|h| self.instance_eval(&h[:proc]) }
                data = JSON.parse(request.body.read)
                result = if action.options[:on_create]
                           klass.new(data["model"]).send(action.name, *data["args"])
                         elsif action.options[:class]
                           klass.send(action.name, *data["args"])
                         else
                           klass[params[:id]].send(action.name, *data["args"])
                         end
                json result
              end
            end
          when klass.subclass_of?(Menilite::Controller)
            klass.action_info.each do |name, action|
              path = klass.respond_to?(:namespace) ? "/#{klass.namespace}/#{action.name}" : "/#{action.name}"
              post path  do
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
