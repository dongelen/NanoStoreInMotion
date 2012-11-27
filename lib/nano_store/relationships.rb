module NanoStore

  class Criteria

    def initialize(klass)
      @klass = klass
    end

    def criteria
      @criteria ||= {:conditions => {}}
    end

    def create(args = {})
      @klass.create(@criteria[:conditions].merge(args))
    end

    def create_or_update(identifiers = {}, attributes = {})
      @klass.create_or_update(identifiers, @criteria[:conditions].merge(attributes))
    end

    def count
      all.count
    end

    def all
      @klass.find(criteria[:conditions])
    end

    def find_by_key(key)
      @klass.find_by_key(key)
    end

    def first
      all.first
    end

    def last
      all.last
    end

    def where(args)
      criteria[:conditions].merge!(args)
      self
    end
  end

  class Relationship

    attr_accessor :name, :type, :options

    def initialize(origin_klass, name, type, options = {})
      @name = name
      @type = type
      @options = options
      if type == :belongs_to
        foreign_key = foreign_key_for_class(klass)
        method_name = "#{klass.to_s.downcase}=".to_sym
        k = klass
        origin_klass.class_eval do
          attribute foreign_key
          define_method method_name do |arg|
            if arg.is_a?(k)
              self.send("#{foreign_key}=".to_sym, arg.key)
              self.save
            else
              raise "BAD RELATIONSHIP"
            end
          end
        end
      end
    end


    def execute(instance)
      case @type
      when :has_many
        execute_has_many(instance)
      when :belongs_to
        execute_belongs_to(instance)
      else
        raise "INVALID TYPE SPECIFIED: #{@type.inspect} (expected has_many or belongs_to)"
      end
    end

    def execute_has_many(instance)
      Criteria.new(klass).where(foreign_key_for_class(instance.class) => instance.key)
    end

    def execute_belongs_to(instance)
      Criteria.new(klass).find_by_key(instance.send(foreign_key_for_class(klass)))
    end

    private
    def klass
      Kernel.const_get((@options[:class] || @name).to_s.camelize)
    end

    def foreign_key_for_class(klass)
      (klass.to_s.downcase + "_key").to_sym
    end
  end
end
