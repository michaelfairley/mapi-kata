require "mapi"
require "sequel"

DB = Sequel.connect('postgres://localhost/microblog_api_kata')

RSpec.configure do |config|
  config.treat_symbols_as_metadata_keys_with_true_values = true
  config.run_all_when_everything_filtered = true
  config.filter_run :focus
  config.order = 'default'
  config.fail_fast = true
end

def random_string(n = 10)
  (0...10).map { (97 + rand(26)).chr }.join
end
