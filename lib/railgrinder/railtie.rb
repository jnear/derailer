#require 'derailer'
require 'rails'
module Derailer
  class Railtie < Rails::Railtie
    railtie_name :derailer

    rake_tasks do
      load "tasks/derailer.rake"
    end
  end
end
