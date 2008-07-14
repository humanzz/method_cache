class MethodCacher
  def self.read(key, raise_exceptions = false)
    value = Rails.cache.read(key)
    begin
      value = Marshal.load(value) unless value.nil?
    rescue ArgumentError => e
      #autorequiring types that have not been yet required
      match = /#<ArgumentError: undefined class\/module (.*)>/.match(e.inspect)
      if match.nil?
        raise if raise_exceptions
        return nil
      end  
      #match[1] can take the forms: Item, Product::Item, Item::, Product::Item::
      missing_constants = match[1].split('::')
      if missing_constants.length == 1
        parent = Kernel
        missing_constant = missing_constants[0]
      else
        parent = missing_constants[0..(missing_constants.length-2)].join('::').constantize
        missing_constant = missing_constants.last
      end
      Dependencies.load_missing_constant parent,missing_constant
      retry
    end
    value
  rescue MemCache::MemCacheError => err
    ActiveRecord::Base.logger.info "MethodCacher.read MemCache Error: #{err.message}"
    raise if raise_exceptions
    nil
  end
  
  def self.write(key, value, expiry = 0, raise_exception = false)
    Rails.cache.write(key,Marshal.dump(value), :expires_in => expiry)
    value
  rescue MemCache::MemCacheError => err
    ActiveRecord::Base.logger.debug "MethodCacher.write MemCache Error: #{err.message}"
    raise if raise_exceptions
    nil
  end
  
  def self.delete(key, raise_exceptions = false)
    Rails.cache.delete(key)
  rescue MemCache::MemCacheError => err
    ActiveRecord::Base.logger.debug "MethodCacher.delete MemCache Error: #{err.message}"
    raise if raise_exceptions
    nil
  end
end

# An add on to Ruby classes which implements multi layered caching to "any method"
# it should be used when calculating the value for the first time is an intensive process (it's not read directly from database for example)
# and when the setter method doesn't update anything i.e. no setter methods as the plugin
# will automatically generate it so that updates are persisted to the cache

module ActiveRecord
  module Espace
    module MethodCache
      def self.included(base)
        base.extend(ClassMethods)
      end
      
      module ClassMethods
        def caches_method(method, options = {})
          include InstanceMethods
          return unless ActionController::Base.perform_caching
          options[:until] = options[:until].to_time.rfc2822 if options[:until] && (options[:until].is_a?(Time) ||options[:until].is_a?(Date))
          options[:for] = options[:for].to_i if options[:for]
          class_eval <<-"end_eval"
          alias_method  :cached_#{method.to_s}, :#{method.to_s}
          def #{method.to_s}
            #needs to get data from cache here
            if @cached_#{method.to_s}.nil?
              @cached_#{method.to_s} = MethodCacher.read("cached_#{method}_for_\#{self.class.name}_\#{@attributes['id']}")
              if @cached_#{method.to_s}.nil?
                @cached_#{method.to_s} = cached_#{method.to_s}
                MethodCacher.write("cached_#{method}_for_\#{self.class.name}_\#{@attributes['id']}",@cached_#{method.to_s}, seconds_to_expire(cached_#{method}_options))
              end
            end
            @cached_#{method.to_s}
          end
          
          def cached_#{method.to_s}_options
            if @cached_#{method}_options.nil?
              @cached_#{method}_options = #{options.inspect}
              if @cached_#{method}_options[:until] && @cached_#{method}_options[:until].is_a?(String) 
                @cached_#{method}_options[:until] = Time.rfc2822(@cached_#{method}_options[:until]) 
              end
            end
            @cached_#{method}_options
          end
          end_eval
        end
        
        def caches_class_method(method, options = {})
          options[:until] = options[:until].rfc2822 if options[:until] && (options[:until].is_a?(Time) ||options[:until].is_a?(Date))
          options[:for] = options[:for].to_i if options[:for]
          return unless ActionController::Base.perform_caching
          class_eval <<-"end_eval"
          class << self
            @@cached_#{method}_options = #{options.inspect}
            cached_data = nil                      
            alias_method  :cached_#{method.to_s}, :#{method.to_s}
            
            def #{method.to_s}
              #needs to get data from cache here
              cached_data = MethodCacher.read("cached_#{method}_for_\#{self.to_s}")
              if cached_data.nil?
                cached_data = cached_#{method.to_s}
                MethodCacher.write("cached_#{method}_for_\#{self.to_s}",cached_data, seconds_to_expire(cached_#{method}_options))
              end
              cached_data
            end
            
            def cached_#{method}_options
              if @@cached_#{method}_options[:until] && @@cached_#{method}_options[:until].is_a?(String) 
                @@cached_#{method}_options[:until] = Time.rfc2822(@@cached_#{method}_options[:until]) 
              end
              @@cached_#{method}_options
            end  
            
            
          end
          end_eval
        end        
        
        def expire_class_method(method)
          return unless ActionController::Base.perform_caching
          MethodCacher.delete("cached_#{method.to_s}_for_#{self.to_s}")
        end
        
        def expire_instance_method(method, id)
          return unless ActionController::Base.perform_caching
          MethodCacher.delete("cached_#{method}_for_#{self.to_s}_#{id}")
        end
        
        def seconds_to_expire(options = {})
          if options.has_key?(:until)
            case options[:until]
              when 'midnight', :midnight
              secs = ((Time.now + 1.day).midnight - Time.now).to_i
            else
              secs = (options[:until] - Time.now).to_i
            end
            raise ":until(#{options[:until].inspect}) is less than Time.now by #{secs}" if secs <= 0
            return secs
          elsif options.has_key?(:for)
            return options[:for].to_i
          else
            0
          end
        end  
      end
      
      module InstanceMethods
        def expire_method(method)
          return unless ActionController::Base.perform_caching
          MethodCacher.delete("cached_#{method.to_s}_for_#{self.class.name}_#{@attributes['id']}")
          remove_instance_variable("@cached_#{method.to_s}".to_sym) if instance_variables.include? "@cached_#{method.to_s}"
        end
        
        #TODO use the class method instead
        def seconds_to_expire(options = {})
          if options.has_key?(:until)
            case options[:until]
              when 'midnight', :midnight
              secs = ((Time.now + 1.day).midnight - Time.now).to_i  
            else
              secs = (options[:until] - Time.now).to_i
            end
            raise ":until(#{options[:until].inspect}) is less than Time.now by #{secs}" if secs <= 0
            return secs
          elsif options.has_key?(:for)
            return options[:for]
          else
            0
          end
        end        
      end
    end  
  end
end

ActiveRecord::Base.send(:include, ActiveRecord::Espace::MethodCache)