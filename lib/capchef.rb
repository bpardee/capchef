require 'rubygems'
require 'erb'
require 'yaml'
require 'json'

module Capchef
  extend self

  # Default to /tmp but allow change in case it is noexec
  def tmpdir
    @tmpdir ||= '/tmp'
  end

  def tmpdir=(tmpdir)
    @tmpdir = tmpdir
  end

  def path
    @path ||= '/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin'
  end

  def path=(path)
    @path = path
  end

  def prepend_path(dir)
    @path = "#{dir}:#{path}"
  end

  # Runs +command+ as root invoking the command with su -c
  # and handling the root password prompt.
  #
  #   surun "/etc/init.d/apache reload"
  #   # Executes
  #   # su - -c '/etc/init.d/apache reload'
  #
  def surun(cap, command, options={})
    @root_password ||= cap.fetch(:root_password, Capistrano::CLI.password_prompt("root password: "))
    cap.run("su -c 'cd; PATH=#{path}; #{command}'", options) do |channel, stream, output|
      puts "[#{channel[:host]}] #{output}" if output
      channel.send_data("#{@root_password}\n") if output && output =~ /^Password:/
      yield channel, stream, output if block_given?
    end
  end

  def surun_script(cap, script, options={})
    raise "No such file: #{script}" unless File.exist?(script)
    basename = File.basename(script)
    script_dir = "#{tmpdir}/#{basename}.#$$"
    remote_script = "#{script_dir}/#{basename}"
    cap.run "mkdir #{script_dir}", options
    cap.upload script, remote_script, options
    cap.run "chmod 0755 #{remote_script}", options
    if block_given?
      yield remote_script
    else
      surun cap, remote_script, options
    end
    cap.run "rm -rf #{script_dir}", options
  end

  def nodes_config
    # The config file might want access to information that is contained within it (all_nodes for instance).
    # If so, make sure the 2nd pass doesn't try to acquire the same info or we will have an endless loop
    @config_pass ||= 0
    @nodes_config ||= begin
      nodes_file = ENV['NODES_FILE'] || 'nodes.yml'
      raise "No file #{nodes_file}" unless File.exist?(nodes_file)
      @config_pass += 1
      config = YAML.load(ERB.new(File.read('nodes.yml')).result(binding))
      @config_pass -= 1
      config
    end
  end

  def all_nodes
    return [] if @config_pass && @config_pass > 1
    return nodes_config.keys
  end
end