Gem::Specification.new do |s|
  s.name              = "roda-rails"
  s.version           = "1.0.0"
  s.summary           = "Integration for using Roda as Rack middleware in a Rails app"
  s.authors           = ["Jeremy Evans"]
  s.email             = ["code@jeremyevans.net"]
  s.homepage          = "https://github.com/jeremyevans/roda-rails"
  s.license           = "MIT"

  s.files = %w'README.rdoc MIT-LICENSE' + Dir['{lib}/**/*.rb']

  s.description = <<END
roda-rails offers integration for Roda when used as Rack middleware in a Rails
application.  It allows the Roda middleware to use Rails flash handling as well
as Rails' CSRF support.
END

  s.add_dependency "roda", '>= 2'
  s.add_dependency "rails", '~> 4.2.0'
end
