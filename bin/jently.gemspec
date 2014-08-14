Gem::Specification.new do |s|
  s.name        = 'jently'
  s.version     = '1.0.2'
  s.date        = '2012-09-11'
  s.summary     = "A Ruby application that allows for communication between the Jenkins CI and Github."
  s.description = "A Ruby application that allows for communication between the Jenkins CI and Github."
  s.authors     = ["Tom Van Eyck"]
  s.email       = 'tomvaneyck@gmail.com'
  s.homepage    = 'https://github.com/vaneyckt/Jently'

  s.add_runtime_dependency 'systemu', '>= 2.6.4'
  s.add_runtime_dependency 'faraday', '>= 0.9.0'
  s.add_runtime_dependency 'octokit', '>= 3.3.0'
  s.add_runtime_dependency 'json',    '>= 1.8.1'
  s.add_runtime_dependency 'pry',     '>= 0.10.0'
  s.add_runtime_dependency 'daemons', '>= 1.1.9'
  s.add_runtime_dependency 'faraday_middleware', '>= 0.9.1'
end
