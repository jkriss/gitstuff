class Post < Hashie::Mash
  def initialize(*hash)
    hash = hash.first if hash.is_a? Array
    convert_date hash, :created_at
    convert_date hash, :modified_at
    super(hash)
  end
  
  def convert_date(hash, attribute_name)
    time_in_seconds = hash["#{attribute_name}_sortable"]
    return unless time_in_seconds
    hash[attribute_name.to_s] = Time.at(time_in_seconds)
  end
end