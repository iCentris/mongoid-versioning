# Mongoid 9 compatible monkey patches for versioning

# Add :versioned option to field validators
if defined?(Mongoid::Fields::Validators::Macro::OPTIONS)
  default_options = Mongoid::Fields::Validators::Macro::OPTIONS
  unless default_options.include?(:versioned)
    Mongoid::Fields::Validators::Macro.send(:remove_const, :OPTIONS)
    Mongoid::Fields::Validators::Macro.send(:const_set, :OPTIONS, default_options + [:versioned])
  end
end

module Mongoid
  module Fields
    class Standard
      # Is this field included in versioned attributes?
      #
      # @return [ true, false ] If the field is included in versioning.
      def versioned?
        @versioned ||= (options[:versioned].nil? ? true : options[:versioned])
      end
    end
  end
end

# Mongoid 9 uses Association instead of Relations
module Mongoid
  module Association
    # Add versioned? method to association metadata
    class Relatable
      def versioned?
        !!options[:versioned]
      end
    end if defined?(Mongoid::Association::Relatable)
  end
end

module Mongoid
  module Hierarchy
    def collect_children
      children = []
      embedded_relations.each_pair do |name, association|
        without_autobuild do
          child = send(name)
          Array.wrap(child).each do |doc|
            children.push(doc)
            children.concat(doc._children) unless association.respond_to?(:versioned?) && association.versioned?
          end if child
        end
      end
      children
    end
  end
end

module Mongoid
  module Threaded
    module Lifecycle
      private

      def _loading_revision
        Threaded.begin_execution("load_revision")
        yield
      ensure
        Threaded.exit_execution("load_revision")
      end

      module ClassMethods
        def _loading_revision?
          Threaded.executing?("load_revision")
        end
      end
    end
  end
end

module Mongoid
  module Document
    module ClassMethods
      def instantiate(attrs = nil, selected_fields = nil, &block)
        attributes = attrs || {}
        doc = allocate
        doc.__selected_fields = selected_fields if doc.respond_to?(:__selected_fields=)
        doc.instance_variable_set(:@attributes, attributes)
        doc.apply_defaults
        yield(doc) if block_given?
        doc.run_callbacks(:find) unless doc._find_callbacks.empty?
        doc.run_callbacks(:initialize) unless doc._initialize_callbacks.empty?
        doc
      end
    end
  end
end
