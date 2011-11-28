require 'digest/sha1'

class ApiKeyManager
  
  def self.key_for_user(user)
    Digest::SHA1.hexdigest "://github.com/#{user}/--#{salt}"
  end
  
  def self.valid_key?(key, url)
    user = /git:\/\/github.com\/([^\/]+)\/[^\/]+\.git/.match(url)[1]
    puts "user: #{user}"
    key_for_user(user) == key
  end
  
  protected
  def self.salt
    "This is the secret salty string"
  end
  
end