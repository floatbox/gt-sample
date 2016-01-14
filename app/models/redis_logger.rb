require "json"

class RedisLogger

  # клевый метод для записи массивов,
  # проверяет есть ли такая переменная, если нет создает пустой массив
  def self.insert(fields, param, suffix = nil)
    store_param = RedisLogger.store_param(param, suffix)

    if $redis[store_param].present?
      data = JSON.parse($redis[store_param])
      data << fields
    else
      data = [ fields ]
    end

    $redis.set store_param, data.to_json
  end

  def self.remove(fields, param, suffix = nil)
    store_param = RedisLogger.store_param(param, suffix)

    if $redis[store_param].present?
      data = JSON.parse($redis[store_param])
      data.delete fields
    else
      data = [ ]
    end

    $redis.set store_param, data.to_json
  end

  def self.save(val, param, suffix = nil, expire = nil)
    store_param = RedisLogger.store_param(param, suffix)
    status = $redis.set store_param, val.to_json
    $redis.expire(store_param, expire) if expire
    status
  end

  def self.get_param(param, suffix = nil)
    JSON.parse $redis[RedisLogger.store_param(param, suffix)] || "{}"
  end

  def self.store_param(param, suffix = nil)
    "#{param}#{ '_' + suffix if suffix}"
  end

end
