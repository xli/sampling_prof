require 'rake/javaextensiontask'
require 'rake/testtask'
require 'rubygems'
require 'bundler/setup'
Rake::JavaExtensionTask.new('sampling_prof')

Rake::TestTask.new(:unit_test) do |t|
  t.libs << 'test'
  t.test_files = FileList['test/*_test.rb']
  t.warning = true
  t.verbose = false
end

Rake::TestTask.new(:bm_test) do |t|
  t.libs << 'test'
  t.test_files = FileList['test/bm/*_test.rb']
  t.warning = true
  t.verbose = false
end

task :default => [:test, :bm_test]

task :test => [:compile, :unit_test]
