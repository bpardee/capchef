require 'capchef'

Capistrano::Configuration.instance.load do
  default_run_options[:pty] = true
  ssh_options[:forward_agent] = true

  namespace :utility do
    desc "execute basic command line functions. ie. cap exec cmd='ps -eaf | grep redis' optional arg: HOSTS=ip1,ip2 (replace cmd with sudo for sudo commands)"
    task :default do
      run(ENV['cmd']) if ENV['cmd']
      Capchef.surun(self, ENV['sudo']) if ENV['sudo']
    end
  end
end

