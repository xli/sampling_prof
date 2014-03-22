Gem::Specification.new do |s|
  s.name = 'sampling_prof'
  s.version = '0.1.5'
  s.summary = 'Simple sampling profiler on JRuby'
  s.description = <<-EOF
SamplingProf is a profiling tool that operates by sampling your running thread stacktrace. The result is statistical approximation, but it allows your code to run near full speed
EOF
  s.license = 'MIT'
  s.authors = ["Xiao Li"]
  s.email = ['swing1979@gmail.com']
  s.homepage = 'https://github.com/xli/sampling_prof'

  s.add_development_dependency('rake-compiler', '~> 0.9', '>= 0.9.2')

  s.files = ['README.md']
  s.files += Dir['lib/**/*']
end
