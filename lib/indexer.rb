class Indexer
  
  @queue = :repo_indexer
  
  def self.perform(user, repo_name)
    repo = Repo.new(user, repo_name)
    repo.reindex_now
  end
  
end