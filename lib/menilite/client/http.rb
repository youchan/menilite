module Menilite
  module Http
    class << self
      def get_json(url, &block)
        (callback, promise) = prepare(url, &block)

        %x(
          fetch(
            url,
            {
              method: 'get',
              headers: {
                'Accept': 'application/json',
                'Content-Type': 'application/json'
              },
              credentials: "same-origin",
            }
          ).then(callback);
        )

        promise
      end

      def post_json(url, data, &block)
        (callback, promise) = prepare(url, &block)

        %x(
          fetch(
            url,
            {
              method: 'post',
              headers: {
                'Accept': 'application/json',
                'Content-Type': 'application/json'
              },
              credentials: "same-origin",
              body: #{data.to_json}
            }
          ).then(callback);
        )

        promise

      end

      private

      def prepare(url, &block)
        promise = nil
        callback = nil

        if block
          handler = ResponseHandler.new
          handler.instance_eval(&block)

          callback = Proc.new do |response|
            if `response.ok`
              %x(
                response.json().then(function(json) {
                  #{handler.success(JSON.from_object(`json`))}
                });
              )
            else
              handler.failure(Native(response))
            end
          end
        else
          promise = Promise.new
          callback = Proc.new {|reponse| promise.resolve(JSON.from_object(response.json)) }
        end

        [callback, promise]
      end
    end

    class ResponseHandler
      def initialize
        @listeners = {}
      end

      def on(evt, &block)
        @listeners[evt] = block
      end

      def success(res)
        @listeners[:success].call(res)
      end

      def failure
        @listeners[:failure].call(res)
      end
    end
  end
end
