#require 'railgrinder'
require 'rails'
module Railgrinder
  class Railtie < Rails::Railtie
    railtie_name :railgrinder

    rake_tasks do
      load "tasks/railgrinder.rake"
    end
  end
end
