module NanoStore
  module ModelInstanceMethods
    def save
      raise NanoStoreError, 'No store provided' unless self.class.store

      error_ptr = Pointer.new(:id)
      self.class.store.addObject(self, error:error_ptr)
      raise NanoStoreError, error_ptr[0].description if error_ptr[0]
      self
    end

    def delete
      raise NanoStoreError, 'No store provided' unless self.class.store
      relationships = self.class.relationships.select {|c| c.type == :has_many && c.options[:dependent] == :destroy }
      relationships.each do |relationship|
        relationship.execute(self).all.each(&:delete)
      end
      error_ptr = Pointer.new(:id)
      self.class.store.removeObject(self, error: error_ptr)
      raise NanoStoreError, error_ptr[0].description if error_ptr[0]
      self
    end

    def update_attributes(attributes = {})
      attributes.each {|k,v| self.send("#{k}=", v) }
      save
      self
    end

    def method_missing(meth, *args, &block)
      if c = self.class.relationships.detect {|c| c.name == meth}
        c.execute(self)
      else
        super
      end
    end

  end

  module ModelClassMethods

    def create_or_update(identifiers = {}, attributes = {})
      existing = self.find(identifiers).first
      if existing
        existing.update_attributes(attributes)
      else
        self.create(attributes)
      end
    end

    # initialize a new object
    def new(data={})
      data.keys.each { |k|
        unless self.attributes.member? k.to_sym
          raise NanoStoreError, "'#{k}' is not a defined attribute for this model"
        end
      }

      object = self.nanoObjectWithDictionary(data)
      object
    end

    def relationships
      @relationships ||= [ ]
    end

    # initialize a new object and save it
    def create(data={})
      object = self.new(data)
      object.save
    end

    def has_many(name, options = {})
      raise "You must provide a name" if name.nil?
      relationships << Relationship.new(self, name, :has_many, options)
    end

    def belongs_to(name, options = {})
      raise "You must provide a name" if name.nil?
      relationships << Relationship.new(self, name, :belongs_to, options)
    end

    def attribute(name)
      @attributes << name

      define_method(name) do |*args, &block|
        self.info[name]
      end

      define_method((name + "=").to_sym) do |*args, &block|
        if args[0].nil?
          self.info.delete(name.to_sym)
        else
          self.info[name] = args[0]
        end
      end
    end

    def attributes
      @attributes
    end

    def store
      if @store.nil?
        return NanoStore.shared_store
      end
      @store
    end

    def store=(store)
      @store = store
    end

    def count
      self.store.count(self)
    end

    def delete(*args)
      keys = find_keys(*args)
      self.store.delete_keys(keys)
    end

    def inherited(subclass)
      subclass.instance_variable_set(:@attributes, [])
      subclass.instance_variable_set(:@store, nil)
    end
  end

  class Model < NSFNanoObject
    include ModelInstanceMethods
    extend ModelClassMethods
    extend ::NanoStore::FinderMethods
  end
end
