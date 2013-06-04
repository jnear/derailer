desc 'run Railgrinder analysis'
task :railgrinder do
  RubiconAnalysis.new do
    rails_path Rails.root

    to_set_current_user do |current_user|
      ApplicationController.send(:define_method, :current_user, lambda { @user = current_user; current_user })
    end
  end
end
