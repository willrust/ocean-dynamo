module OceanDynamo
  module HasMany

    def self.included(base)
      base.extend(ClassMethods)
    end
  

    # ---------------------------------------------------------
    #
    #  Class methods
    #
    # ---------------------------------------------------------

    module ClassMethods


      #
      # Defines a +has_many+ relation to a +belongs_to+ class.
      #
      # The +dependent:+ keyword arg may be +:destroy+, +:delete+ or +:nullify+
      # and have the same semantics as in ActiveRecord. With +:nullify+, however,
      # the hash key is set to the string "NULL" rather than binary NULL, as
      # DynamoDB doesn't permit storing empty fields.
      #
      def has_many(children, dependent: :nullify)            # :children
        children_attr = children.to_s.underscore             # "children"
        class_name = children_attr.classify                  # "Child"
        define_class_if_not_defined(class_name)
        child_class = class_name.constantize                 # Child
        register_relation(child_class, :has_many)

        # Handle children= after create and update
        after_save do |p|
          new_children = instance_variable_get("@#{children_attr}")  
          if new_children  # TODO: only do this for dirty collections
            write_children child_class, new_children
            map_children child_class do |c|
              next if new_children.include?(c)
              c.destroy
            end
          end 
          true
        end

        if dependent == :destroy
          before_destroy do |p|
            map_children(child_class, &:destroy)
            p.instance_variable_set "@#{children_attr}", nil
            true
          end

        elsif dependent == :delete
          before_destroy do |p|
            delete_children(child_class)
            p.instance_variable_set "@#{children_attr}", nil
         end

        elsif dependent == :nullify
          before_destroy do |p|
            nullify_children(child_class)
            p.instance_variable_set "@#{children_attr}", nil
            true
          end

        else
          raise ArgumentError, ":dependent must be :destroy, :delete, or :nullify"
        end

        # Define accessors for instances
        attr_accessor children_attr
        self.class_eval "def #{children_attr}(force_reload=false) 
                           @#{children_attr} = false if force_reload
                           @#{children_attr} ||= read_children(#{child_class})
                         end"
        self.class_eval "def #{children_attr}=(value)
                           @#{children_attr} = value
                         end"
        self.class_eval "def #{children_attr}? 
                           @#{children_attr} ||= read_children(#{child_class})
                           @#{children_attr}.present?
                         end"
      end

    end


    # ---------------------------------------------------------
    #
    #  Instance variables and methods
    #
    # ---------------------------------------------------------


    #
    # Sets all has_many relations to nil.
    #
    def reload(*)
      result = super

      self.class.relations_of_type(:has_many).each do |klass|
        attr_name = klass.to_s.pluralize.underscore
        instance_variable_set("@#{attr_name}", nil)
      end

      result
    end


    protected

    #
    # Reads all children of a has_many relation.
    #
    def read_children(child_class)  # :nodoc:
      if new_record? 
        nil
      else
        result = Array.new
        _late_connect?
        child_items = child_class.dynamo_items
        child_items.query(hash_value: id, range_gte: "0",
                          batch_size: 1000, select: :all) do |item_data|
          result << child_class.new._setup_from_dynamo(item_data)
        end
        result
      end
    end


    #
    # Write all children in the arg, which should be nil or an array.
    #
    def write_children(child_class, arg)  # :nodoc:
      return nil if arg.blank?
      raise AssociationTypeMismatch, "not an array or nil" if !arg.is_a?(Array)
      raise AssociationTypeMismatch, "an array element is not a #{child_class}" unless arg.all? { |m| m.is_a?(child_class) }
      # We now know that arg is an array containing only members of the child_class
      arg.each(&:save!)
      arg
    end


    #
    # Takes a block and yields each child to it. Batched for scalability.
    #
    def map_children(child_class)
      return if new_record?
      child_items = child_class.dynamo_items
      child_items.query(hash_value: id, range_gte: "0", 
                        batch_size: 1000, select: :all) do |item_data|
        yield child_class.new._setup_from_dynamo(item_data)
      end
    end


    # 
    # Delete all children without instantiating them first.
    # 
    def delete_children(child_class)
      return if new_record?
      child_items = child_class.dynamo_items
      child_items.query(hash_value: id, range_gte: "0", 
                        batch_size: 1000) do |item|
        item.delete
      end
    end


    #
    # Set the hash key values of all children to the string "NULL", thereby turning them
    # into orphans. Note that we're not setting the key to NULL as this isn't possible
    # in DynamoDB. Instead, we're using the literal string "NULL".
    #
    def nullify_children(child_class)
      return if new_record?
      child_items = child_class.dynamo_items
      child_items.query(hash_value: id, range_gte: "0", 
                        batch_size: 1000, select: :all) do |item_data|
        attrs = item_data.attributes
        item_data.item.delete
        attrs[child_class.table_hash_key.to_s] = "NULL"
        child_items.create attrs
      end
    end

  end
end
