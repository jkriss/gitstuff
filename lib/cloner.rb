class Cloner
  
  @queue = :repo_cloner
  
  def self.perform(user, name, clone_url)
    puts "-- cloning #{clone_url}"
    Repo.clone_now(user, name, clone_url)
  end
  
end