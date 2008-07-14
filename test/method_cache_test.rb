require 'test/unit'
require File.join(File.dirname(__FILE__), 'abstract_unit')
require File.join(File.dirname(__FILE__), 'dummy_classes')

class MethodCacheTest < Test::Unit::TestCase
  
  fixtures :cars
  
  def setup
    ActionController::Base.perform_caching = true
    ActionController::Base.cache_store = :mem_cache_store, "localhost"
  end
  
  def test_method_cacher
    MethodCacher.write('koko','soso',0,true)
    assert_equal 'soso', MethodCacher.read('koko')
    MethodCacher.delete 'koko'
    assert_nil MethodCacher.read('koko')
  end
  
  def test_method_cacher_with_time
    MethodCacher.write('koko','soso',3,true)
    assert_equal 'soso', MethodCacher.read('koko')
    sleep 3
    assert_nil MethodCacher.read('koko')
  end
  
  # Replace this with your real tests.
  def test_caches_method
    c = Car.find :first
    assert !c.instance_variables.include?("@cached_costy_method")
    assert_equal "costy_method", c.costy_method
    assert c.instance_variables.include?("@cached_costy_method")
    assert_equal "costy_method", MethodCacher.read("cached_costy_method_for_#{Car.name}_#{c.id}", true)
  end
  
  def test_expire_method
    c = Car.find :first
    c.costy_method
    assert c.instance_variables.include?("@cached_costy_method")
    assert_equal "costy_method", MethodCacher.read("cached_costy_method_for_#{Car.name}_#{c.id}", true)
    assert c.instance_variables.include?("@cached_costy_method")
    
    c.expire_method :costy_method
    assert !c.instance_variables.include?("@cached_costy_method")
    assert_nil MethodCacher.read("cached_costy_method_for_#{Car.name}_#{c.id}", true)
  end
  
  def test_expire_instance_method
    c = Car.find :first
    c.costy_method
    assert_equal "costy_method", MethodCacher.read("cached_costy_method_for_#{Car.name}_#{c.id}", true)
    
    Car.expire_instance_method :costy_method, c.id
    assert_nil MethodCacher.read("cached_costy_method_for_#{Car.name}_#{c.id}", true)
  end
  
  def test_caches_method_with_for
    c = Car.find :first
    MethodCacher.delete("cached_for_costy_method_for_#{Car.name}_#{c.id}", true)
    assert_nil MethodCacher.read("cached_for_costy_method_for_#{Car.name}_#{c.id}", true)
    assert_equal "for_costy_method", c.for_costy_method
    assert_equal "for_costy_method", MethodCacher.read("cached_for_costy_method_for_#{Car.name}_#{c.id}", true)
    sleep 5
    assert_nil MethodCacher.read("cached_for_costy_method_for_#{Car.name}_#{c.id}", true)
  end
  
#  def test_caches_method_with_until
#    c = Car.find :first
#    MethodCacher.delete("cached_until_costy_method_for_#{Car.name}_#{c.id}", true)
#    assert_nil MethodCacher.read("cached_until_costy_method_for_#{Car.name}_#{c.id}", true)
#    puts "about to call c.until_costy_method #{Time.now.inspect}"
#    assert_equal "until_costy_method", c.until_costy_method
#    puts "after calling c.until_costy_method #{Time.now.inspect}"
#    assert_equal "until_costy_method", MethodCacher.read("cached_until_costy_method_for_#{Car.name}_#{c.id}", true)
#    sleep 8
#    assert_nil MethodCacher.read("cached_until_costy_method_for_#{Car.name}_#{c.id}", true)
#  end
  
  def test_caches_class_method
    assert_nil MethodCacher.read("cached_costy_class_method_for_#{Car.name}", true)
    assert_equal "costy_class_method", Car.costy_class_method
    assert_equal "costy_class_method", MethodCacher.read("cached_costy_class_method_for_#{Car.name}", true)
    MethodCacher.delete("cached_costy_class_method_for_#{Car.name}", true)
  end
  
  def test_expire_class_method
    assert_nil MethodCacher.read("cached_costy_class_method_for_#{Car.name}", true)
    assert_equal "costy_class_method", Car.costy_class_method
    assert_equal "costy_class_method", MethodCacher.read("cached_costy_class_method_for_#{Car.name}", true)
    
    Car.expire_class_method :costy_class_method
    assert_nil MethodCacher.read("cached_costy_class_method_for_#{Car.name}", true)
  end
  
  def test_caches_class_method_with_for
    MethodCacher.delete("cached_for_costy_class_method_for_#{Car.name}", true)
    assert_nil MethodCacher.read("cached_for_costy_class_method_for_#{Car.name}", true)
    assert_equal "for_costy_class_method", Car.for_costy_class_method
    assert_equal "for_costy_class_method", MethodCacher.read("cached_for_costy_class_method_for_#{Car.name}", true)
    sleep 5
    assert_nil MethodCacher.read("cached_for_costy_class_method_for_#{Car.name}", true)
  end
  
#  def test_caches_class_method_with_until
#    MethodCacher.delete("cached_until_costy_class_method_for_#{Car.name}", true)
#    assert_nil MethodCacher.read("cached_until_costy_class_method_for_#{Car.name}", true)
#    assert_equal "until_costy_class_method", Car.until_costy_class_method
#    assert_equal "until_costy_class_method", MethodCacher.read("cached_until_costy_class_method_for_#{Car.name}", true)
#    sleep 8
#    assert_nil MethodCacher.read("cached_until_costy_class_method_for_#{Car.name}", true)
#  end
end
