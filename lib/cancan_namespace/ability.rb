module CanCanNamespace

  # This module is designed to be included into an Ability class. This will
  # provide the "can" methods for defining and checking abilities.
  #
  #   class Ability
  #     include CanCan::Ability
  #
  #     def initialize(user)
  #       if user.admin?
  #         can :manage, :all
  #       else
  #         can :read, :all
  #       end
  #     end
  #   end
  #
  module Ability
    include CanCan::Ability
    
    def can?(action, subject, *extra_args)
      context = extra_args.pop[:context] if extra_args.last.kind_of?(Hash) && extra_args.last.key?(:context)
      
      match = relevant_rules_for_match(action, subject, context).detect do |rule|
        rule.matches_conditions?(action, subject, extra_args)
      end
      match ? match.base_behavior : false
    end
    
    def can(action = nil, subject = nil, conditions = nil, &block)
      rules << CanCanNamespace::Rule.new(true, action, subject, conditions, &block)
    end
    
    def cannot(action = nil, subject = nil, conditions = nil, &block)
      rules << CanCanNamespace::Rule.new(false, action, subject, conditions, &block)
    end

    def model_adapter(model_class, action, context = nil)
      adapter_class = CanCan::ModelAdapters::AbstractAdapter.adapter_class(model_class)
      adapter_class.new(model_class, relevant_rules_for_query(action, model_class, context))
    end

    def has_block?(action, subject, context = nil)
      relevant_rules(action, subject, context).any?(&:only_block?)
    end

    def attributes_for(action, subject, context = nil)
      attributes = {}
      relevant_rules(action, subject, context).each do |rule|
        attributes.merge!(rule.attributes_from_conditions) if rule.base_behavior
      end
      attributes
    end
    
    private
    
      # Returns an array of Rule instances which match the action and subject
      # This does not take into consideration any hash conditions or block statements
      def relevant_rules(action, subject, context = nil)
        rules.reverse.select do |rule|
          rule.expanded_actions = expand_actions(rule.actions)
          rule.relevant? action, subject, context
        end
      end
    
      def relevant_rules_for_match(action, subject, context = nil)
        relevant_rules(action, subject, context).each do |rule|
          if rule.only_raw_sql?
            raise CanCan::Error, "The can? and cannot? call cannot be used with a raw sql 'can' definition. The checking code cannot be determined for #{action.inspect} #{subject.inspect}"
          end
        end
      end

      def relevant_rules_for_query(action, subject, context = nil)
        relevant_rules(action, subject, context).each do |rule|
          if rule.only_block?
            raise CanCan::Error, "The accessible_by call cannot be used with a block 'can' definition. The SQL cannot be determined for #{action.inspect} #{subject.inspect}, context: #{context.inspect}"
          end
        end
      end
  end
end
