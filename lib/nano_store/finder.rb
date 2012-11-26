module NanoStore
  module FinderMethods

    def first
      all.first
    end

    def last
      all.last
    end

    def all(*args)
      if args[0].is_a?(Hash)
        sort_options = args[0][:sort] || {}
      else
        sort_options = {}
      end

      if sort_options.empty?
        self.store.objectsOfClassNamed(self.bare_class_name)
      else
        sort_descriptors = sort_descriptor_with_options(sort_options)
        self.store.objectsOfClassNamed(self.bare_class_name, usingSortDescriptors:sort_descriptors)
      end
    end

    # find model by criteria
    #
    # Return array of models
    #
    # Examples:
    #   User.find(:name, NSFEqualTo, "Bob") # => [<User#1>]
    #   User.find(:name => "Bob") # => [<User#1>]
    #   User.find(:name => {NSFEqualTo => "Bob"}) # => [<User#1>]
    #
    def find(*arg)
      if arg[0].is_a?(Hash)
        # hash style
        options = arg[0]
        if arg[1] && arg[1].is_a?(Hash)
          sort_options = arg[1][:sort] || {}
        else
          sort_options = {}
        end
      elsif arg[0] && arg[1] && arg[2]
        # standard way to find
        options = {arg[0] => {arg[1] => arg[2]}}
        if arg[4] && arg[4].is_a?(Hash)
          sort_options = arg[4][:sort] || {}
        else
          sort_options = {}
        end
      elsif arg.empty?
        options = {}
        sort_options = {}
      else
        raise "unexpected parameters #{arg}"
      end
      search = NSFNanoSearch.searchWithStore(self.store)

      expressions = expressions_with_options(options)
      search.expressions = expressions

      sort_descriptors = sort_descriptor_with_options(sort_options)
      search.sort = sort_descriptors
      search.filterClass = self.bare_class_name

      error_ptr = Pointer.new(:id)
      searchResults = search.searchObjectsWithReturnType(NSFReturnObjects, error:error_ptr)
      raise NanoStoreError, error_ptr[0].description if error_ptr[0]

      searchResults
    end

    # find model keys by criteria
    #
    # Return array of keys
    #
    # Examples:
    #   User.find_keys(:name, NSFEqualTo, "Bob") # => ["1"]
    #   User.find_keys(:name => "Bob") # => ["1"]
    #   User.find_keys(:name => {NSFEqualTo => "Bob"}) # => ["1"]
    #
    def find_keys(*arg)
      if arg[0].is_a?(Hash)
        # hash style
        options = arg[0]
        if arg[1] && arg[1].is_a?(Hash)
          sort_options = arg[1][:sort] || {}
        else
          sort_options = {}
        end
      elsif arg[0] && arg[1] && arg[2]
        # standard way to find
        options = {arg[0] => {arg[1] => arg[2]}}
        if arg[4] && arg[4].is_a?(Hash)
          sort_options = arg[4][:sort] || {}
        else
          sort_options = {}
        end
      elsif arg.empty?
        options = {}
        sort_options = {}
      else
        raise "unexpected parameters #{arg}"
      end

      search = NSFNanoSearch.searchWithStore(self.store)

      expressions = expressions_with_options(options)
      search.expressions = expressions

      sort_descriptors = sort_descriptor_with_options(sort_options)
      search.sort = sort_descriptors
      search.filterClass = self.bare_class_name

      error_ptr = Pointer.new(:id)
      searchResults = search.searchObjectsWithReturnType(NSFReturnKeys, error:error_ptr)
      raise NanoStoreError, error_ptr[0].description if error_ptr[0]

      searchResults
    end

    # find a model by key
    #
    # Return an object or nil (if not found)
    #
    # Examples:
    # User.find_by_key(my_key)
    def find_by_key(key)
      search = NSFNanoSearch.searchWithStore(self.store)
      search.key = key

      error_ptr = Pointer.new(:id)
      searchResult = search.searchObjectsWithReturnType(NSFReturnObjects, error:error_ptr).first
      raise NanoStoreError, error_ptr[0].description if error_ptr[0]

      searchResult.last if searchResult
    end

    def bare_class_name
      self.to_s.split("::").last
    end

    private
    def expressions_with_options(options)
      expressions = []

      options.each do |key, val|
        attribute = NSFNanoPredicate.predicateWithColumn(NSFAttributeColumn, matching:NSFEqualTo, value:key.to_s)
        expression = NSFNanoExpression.expressionWithPredicate(attribute)
        if val.is_a?(Hash)
          val.each do |operator, sub_val|
            value = NSFNanoPredicate.predicateWithColumn(NSFValueColumn, matching:operator, value:sub_val)
            expression.addPredicate(value, withOperator:NSFAnd)
          end
        elsif val.is_a?(Array)
          value = NSFNanoPredicate.predicateWithColumn(NSFValueColumn, matching:NSFEqualTo, value:val.pop)
          expression.addPredicate(value, withOperator:NSFAnd)

          val.each do |sub_val|
            value = NSFNanoPredicate.predicateWithColumn(NSFValueColumn, matching:NSFEqualTo, value:sub_val)
            expression.addPredicate(value, withOperator:NSFOr)
          end
        else
          value = NSFNanoPredicate.predicateWithColumn(NSFValueColumn, matching:NSFEqualTo, value:val)
          expression.addPredicate(value, withOperator:NSFAnd)
        end
        expressions << expression
      end
      return expressions
    end

    SORT_MAPPING = {
      'asc' => true,
      'desc' => false,
    }

    def sort_descriptor_with_options(options)
      sorter = options.collect do |opt_key, opt_val|
        if SORT_MAPPING.keys.include?(opt_val.to_s.downcase)
          NSFNanoSortDescriptor.alloc.initWithAttribute(opt_key.to_s, ascending:SORT_MAPPING[opt_val.to_s.downcase])
        else
          raise "unsupported sort parameters: #{opt_val}"
        end
      end
    end
  end # module FinderMethods
end # module NanoStore
