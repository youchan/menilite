module Menilite
  class Privilege
    def key
      raise NotImplementedError.new "Menilite::Privilege#key must be overriden"
    end

    def filter
      {}
    end

    def check_ceate(opt)
      true
    end

    def check_update(opt)
      true
    end

    def check_delete(opt)
      true
    end

    def check(action, opts)
      case action
      when :create
        check_ceate(opt)
      when :update
        check_ceate(opt)
      when :delete
        check_ceate(opt)
      end
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
    end

    def self.current
      Thread.current.thread_variable_get(:previlege_service)
    end

    def get_privileges(names)
      names.map{|key| @privileges.find{|p| p.key == key } }.compact
    end
  end
end
