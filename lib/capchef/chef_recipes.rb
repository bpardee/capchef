require 'erb'
require 'yaml'
require 'json'
require 'tempfile'
require 'zlib'
require 'archive/tar/minitar'
require 'capchef'
include Archive::Tar
  
Capistrano::Configuration.instance.load do
  # User settings
  #set :user, 'deploy' unless exists?(:user)
  #set :group,'www-data' unless exists?(:group)
  
  # Git settings for capistrano
  default_run_options[:pty] = true
  ssh_options[:forward_agent] = true

  namespace :chef do
    desc 'Install chef recipes on remote machines.'
    task :default do
      Capchef.prepend_path(chef_solo_path) if exists?(:chef_solo_path)

      config = Capchef.nodes_config
      remote_tmpdir = "/tmp/chef_solo.#$$"
      run "mkdir #{remote_tmpdir}"
      remote_node_file = "#{remote_tmpdir}/node.json"
      remote_solo_file = "#{remote_tmpdir}/solo.rb"
      remote_cookbooks_tgz = "#{remote_tmpdir}/cookbooks.tgz"
      remote_roles_tgz = "#{remote_tmpdir}/roles.tgz"

      valid_hosts = []
      find_servers_for_task(current_task).each do |s|
        host_config = config[s.host]
        if host_config
          valid_hosts << s.host
          put host_config.to_json, remote_node_file, :hosts => s.host
        else
          $stderr.puts "WARNING: #{s.host} not configured in nodes.yml, skipping"
        end
      end
      if valid_hosts.empty?
        $stderr.puts 'No configured hosts'
        exit 1
      end

      solo_rb = "file_cache_path '/etc/chef'\ncookbook_path '/etc/chef/cookbooks'\nrole_path '/etc/chef/roles'\n"
      put solo_rb, remote_solo_file, :hosts => valid_hosts
      begin
        tmp_cookbooks_tgz = Tempfile.new('cookbooks')
        Dir.chdir('chef-repo') do
          Minitar.pack('cookbooks', Zlib::GzipWriter.new(tmp_cookbooks_tgz))
          tmp_cookbooks_tgz.close
          upload tmp_cookbooks_tgz.path, remote_cookbooks_tgz, :hosts => valid_hosts

          sio_roles_tgz = StringIO.new
          gzip = Zlib::GzipWriter.new(sio_roles_tgz)
          Minitar::Writer.open(gzip) do |tar|
          #Minitar::Writer.open(sio_roles_tgz) do |tar|
            Find.find('roles') do |role_file|
              # TODO: This does not work (how do I specify a role in JSON?
              if role_file.match(/\.yml$/)
                data = YAML.load(ERB.new(File.read(role_file), nil, '-').result(binding)).to_json
                new_role_file = role_file.sub(/\.yml$/, '.json')
                tar.add_file_simple(new_role_file, :size=>data.size, :mode=>0644, :mtime=>File.mtime(role_file)) { |f| f.write(data) }
              else
                Minitar.pack_file(role_file, tar)
              end
            end
          end
          gzip.close
          put sio_roles_tgz.string, remote_roles_tgz, :hosts => valid_hosts
        end
        Capchef.surun(self, [
            'mkdir -p /etc/chef',
            'cd /etc/chef',
            'rm -rf cookbooks roles',
            "tar zxf #{remote_cookbooks_tgz}",
            "tar zxf #{remote_roles_tgz}",
            "chef-solo -c #{remote_solo_file} -j #{remote_node_file}"
        ], :hosts => valid_hosts)
      ensure
        tmp_cookbooks_tgz.unlink
        run "rm -rf #{remote_tmpdir}"
      end
    end
  end
end
