require "sequel"

DEFAULT_DB = Sequel.connect('postgres://localhost/')

DEFAULT_DB.run("DROP DATABASE IF EXISTS microblog_api_kata")
DEFAULT_Sequel.connect('postgres://localhost/microblog_api_kata')

DB = Sequel.connect('postgres://localhost/microblog_api_kata')

DB.create_table :users do
  String :username, :text => true
  String :password, :text => true
  String :realname, :text => true
end
