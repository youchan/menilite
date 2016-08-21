if RUBY_ENGINE == 'opal'
  require 'browser/http'
  require 'opal-parser'
end

module Menilite
  class Controller
    unless RUBY_ENGINE == 'opal'
      def initialize(session, settings)
        @settings = settings
        @session = session
      end
    end

    def session
      @session
    end

    def settings
      @settings
    end

    class << self
      def action_info
        @action_info ||= {}
      end

      def before_action_handlers
        @before_action_handlers ||= []
      end

      ActionInfo = Struct.new(:name, :args, :options)

      def action(name, options = {}, &block)
        action_info[name.to_s] = ActionInfo.new(name, block.parameters, options)
        if RUBY_ENGINE == 'opal'
          method = Proc.new do |*args, &callback| # todo: should adopt keyword parameters
            action_url = self.respond_to?(:namespace) ? "api/#{self.class.namespace}/#{name}" : "api/#{name}"
            post_data = {}
            post_data[:args] = args
            Browser::HTTP.post(action_url, post_data.to_json) do
              on :success do |res|
                callback.call(:success, res) if callback
              end

              on :failure do |res|
                callback.call(:failure, res) if callback
              end
            end
          end
          self.instance_eval do
            define_singleton_method(name, method)
          end
        else
          self.instance_eval do
            define_method(name, block)
          end
        end
      end

      def before_action(options = {}, &block)
        before_action_handlers << { proc: block, options: options }
      end
    end
  end
end
