class ElasticSearch
  include HTTParty
  base_uri 'http://localhost:9200'
  format :json
  
  def self.index_post(user, repo, slug, post_data)
    self.put "/#{user}/#{repo}/#{slug}", :body => post_data.to_json
  end
  
  def self.get_post(user, repo, slug)
    result = self.get "/#{user}/#{repo}/#{slug}"
    result['_source']
  end
  
  def self.search(user, repo, query)
    self.get "/#{user}/#{repo}/_search?q=#{query}"
  end
  
  def self.clear(user, repo)
    self.delete "/#{user}/#{repo}"
  end
end