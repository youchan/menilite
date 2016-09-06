module Menilite
  module Helper
    def server?
      !client?
    end

    def client?
      RUBY_ENGINE == 'opal'
    end

    def if_server(&block)
      block.call if server?
    end

    def if_client(&block)
      block.call if client?
    end
  end

  class << self
    include Helper
  end
end
