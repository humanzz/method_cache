ActiveRecord::Schema.define(:version => 0) do

  create_table :cars, :force => true do |t|
    t.string :name
    
    t.timestamps
  end
  
end
