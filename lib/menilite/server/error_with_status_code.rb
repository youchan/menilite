module Menilite
  class ErrorWithStatusCode < StandardError
    def self.code(code)
      klazz = Class.new(ErrorWithStatusCode)
      klazz.instance_eval do
        define_method(:code) { code }
      end
      klazz
    end

    def code
      500
    end
  end

  BadRequest = ErrorWithStatusCode.code(400)
  Unauthorized = ErrorWithStatusCode.code(401)
  PaymentRequired = ErrorWithStatusCode.code(402)
  NotFound = ErrorWithStatusCode.code(404)
  InternalServerError = ErrorWithStatusCode.code(500)
  NotImplemented = ErrorWithStatusCode.code(501)
end
