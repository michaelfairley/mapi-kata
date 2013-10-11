require "sequel"

DEFAULT_DB = Sequel.connect('postgres://localhost/')

DEFAULT_DB.run("DROP DATABASE IF EXISTS microblog_api_kata")
DEFAULT_DB.run("CREATE DATABASE microblog_api_kata")

DB = Sequel.connect('postgres://localhost/microblog_api_kata')

DB.create_table :users do
  primary_key :id
  String :username, :text => true
  String :password, :text => true
  String :realname, :text => true, :unique => true
end

DB.create_table :tokens do
  String :value, :text => true
  Integer :user_id
end
