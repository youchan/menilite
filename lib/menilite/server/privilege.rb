module Menilite
  class Privilege
    def key
      raise NotImplementedError.new "Menilite::Privilege#key must be overriden"
    end

    def filter
      {}
    end

    def fields
      {}
    end
  end

  class PrivilegeService
    attr_reader :privileges

    def initialize
      @privileges = []
    end

    def self.init
      instance = PrivilegeService.new
      Thread.current.thread_variable_set(:previlege_service, instance)
      @disable = false
    end

    def self.current
      return nil if @disable
      Thread.current.thread_variable_get(:previlege_service)
    end

    def self.disable(&block)
      @disable = true
      block.call
    ensure
      @disable = false
    end

    def get_privileges(names)
      names.map{|key| @privileges.find{|p| p.key == key } }.compact
    end
  end
end
