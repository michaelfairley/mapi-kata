require "restclient"
require "json"

class MAPI
  def self.uri(path)
    "http://localhost:12346#{path}"
  end

  def self.create_user(details={})
    details[:username] ||= random_string(8)
    details[:password] ||= random_string(10)
    details[:real_name] ||= [random_string(8).capitalize, random_string(8).capitalize].join(" ")

    post("/users", details)
  end

  def self.create_token(username, password)
    post("/tokens", {:username => username, :password => password})
  end

  def self.get_user(username)
    get_json("/users/#{username}")
  end

  def self.get_json(path)
    response = get(path)
    response.code.should == 200
    JSON.parse(response.body)
  end

  def self.get(path)
    url = uri(path)

    RestClient.get(url) do |response|
      response
    end
  end

  def self.post(path, params={})
    url = uri(path)

    RestClient.post(url, JSON.dump(params)) do |response|
      response
    end
  end
end
