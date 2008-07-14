class Car < ActiveRecord::Base
  
  def self.costy_class_method
    "costy_class_method"
  end
  
  def self.until_costy_class_method
    "until_costy_class_method"
  end
  
  def Car.for_costy_class_method
    "for_costy_class_method"
  end
  
  def costy_method
    "costy_method"
  end
  
  def for_costy_method
    "for_costy_method"
  end
  
  def until_costy_method
    "until_costy_method"
  end
  
  caches_method :costy_method
  caches_method :for_costy_method, :for => 5.seconds
  caches_method :until_costy_method, :until => 8.seconds.from_now
  
  caches_class_method :costy_class_method
  caches_class_method :for_costy_class_method, :for => 5.seconds
  caches_class_method :until_costy_class_method, :until => 8.seconds.from_now
end
