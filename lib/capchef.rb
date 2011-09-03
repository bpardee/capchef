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
    # TBD - We can change this to use /tmp as its no longer noexec
    raise "No such file: #{script}" unless File.exist?(script)
    basename = File.basename(script)
    tmpdir = "/tmp/#{basename}.#$$"
    remote_script = "#{tmpdir}/#{basename}"
    cap.run "mkdir #{tmpdir}", options
    cap.upload script, remote_script, options
    cap.run "chmod 0755 #{remote_script}", options
    if block_given?
      yield remote_script
    else
      surun cap, remote_script, options
    end
    cap.run "rm -rf #{tmpdir}", options
  end
end