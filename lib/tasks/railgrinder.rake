desc 'run Railgrinder analysis'
task :run_analysis do
  RubiconAnalysis.new do
    rails_path Rails.root

    to_set_current_user do |current_user|
      ApplicationController.send(:define_method, :current_user, lambda { current_user })
    end
  end
end