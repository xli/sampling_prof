require 'rake/javaextensiontask'
require 'rake/testtask'
require 'rubygems'
require 'bundler/setup'
Rake::JavaExtensionTask.new('sampling_prof')

Rake::TestTask.new(:test) do |t|
  t.libs << 'test'
  t.test_files = FileList['test/*_test.rb']
  t.warning = true
  t.verbose = false
end

task :default => [:compile, :test]
