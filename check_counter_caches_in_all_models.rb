#!/usr/bin/env ./script/runner

counter_caches = []

Dir.glob(RAILS_ROOT + '/app/models/*.rb').each { |file| require file }
Object.subclasses_of(ActiveRecord::Base).each do |model|
  model.reflect_on_all_associations.select do |counter_cache_association_reflection|
    counter_cache_association_reflection.macro == :belongs_to && !counter_cache_association_reflection.options[:counter_cache].nil?
  end.each do |counter_cache_association_reflection|
    counter_cache = {
      :association => counter_cache_association_reflection.active_record.class_name.underscore.pluralize,
      :polymorphic => counter_cache_association_reflection.options[:polymorphic]
    }
    if counter_cache_association_reflection.options[:polymorphic]
      counter_cache[:model] = counter_cache_association_reflection.active_record
    else
      counter_cache[:model] = counter_cache_association_reflection.class_name.constantiz
    end
    if counter_cache_association_reflection.options[:counter_cache] == true
      counter_cache[:counter] = counter_cache[:association] + '_count'
    else
      counter_cache[:counter] = counter_cache_association_reflection.options[:counter_cache].to_s
    end
    counter_caches << counter_cache
  end
end

counter_caches.each do |counter_cache|
  puts
  puts "Checking counter cache: #{counter_cache.inspect}"
  if counter_cache[:polymorphic]
    models = []
    begin
      counter_cache[:model].find(:all, :select => 'DISTINCT ON (subject_type) *').collect(&:subject_type).each do |model_name|
        models << model_name.constantize
        puts "Using polymorphic association on model: #{model_name}"
      end
    rescue ActiveRecord::StatementInvalid => e
      puts
      puts "#{counter_cache[:model]}::#{counter_cache[:association]}_count: skipping due to:"
      puts "ActiveRecord::StatementInvalid : #{e}"
      puts
    end
  else
    models = [counter_cache[:model]]
  end
  models.each do |model|
    model.find_in_batches(:batch_size => 100) do |objects|
      objects.each do |object|
        next unless object.respond_to?(counter_cache[:association])
        next if object.send(counter_cache[:association]).count == object.send("#{counter_cache[:association]}_count")
        puts "!!!!!!!!!!!! #{model}::#{counter_cache[:association]}_count inconsitent #{model}##{object.id}"
        puts
        break
      end
    end
  end
end
