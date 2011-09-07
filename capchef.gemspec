Gem::Specification.new do |s|
  s.name = "capchef"
  s.summary = 'Chef capistrano recipes'
  s.description = 'Chef capistrano recipes so you can configure your machines without a server'
  s.authors = ['Brad Pardee']
  s.email = ['bradpardee@gmail.com']
  s.homepage = 'http://github.com/ClarityServices/capchef'
  s.files = Dir["{lib}/**/*"] + %w(LICENSE.txt Rakefile README.md)
  s.version = '0.0.2'
  s.add_dependency 'capistrano'
  s.add_dependency 'json'
  s.add_dependency 'minitar'
end
